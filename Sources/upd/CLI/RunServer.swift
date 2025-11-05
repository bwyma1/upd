import ArgumentParser
import NIO
import ServiceLifecycle
import Foundation
import Logging
import bedrock
import bedrock_fifo
import RAW_dh25519
import RAW
import wireguard_userspace_nio
//import SwiftSlash

actor PeerActivity {
	var peerLastTimeActive:[Peer:NIODeadline] = [:]
	func recordTime(peer:Peer, time:NIODeadline) {
		peerLastTimeActive[peer] = time
	}
	func checkInactivity() -> [Peer] {
		let now = NIODeadline.now()
		var inactivePeers:[Peer] = []
		for (peer, time) in peerLastTimeActive {
			if (now - time > .seconds(240)) {
				inactivePeers.append(peer)
			}
		}
		return inactivePeers
	}
}

struct MainJournalService:Service {
	var databasePath:bedrock.Path = CLI.defaultDBBasePath()
	var myPort:Int
	var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>
	let inactiveNotificationFunc: @Sendable (Peer) async throws -> Void
	func run() async throws {
		var tempLogger = Logger(label: "system-uptime-tool")
		tempLogger.logLevel = .debug
		let cliLogger = tempLogger
		
		// Load peer config file
		let homeDirectory = bedrock.Path(FileManager.default.homeDirectoryForCurrentUser.path)
		let jsonURL = URL(fileURLWithPath: homeDirectory.appendingPathComponent("peer-config.json").path())
		let cfg = try loadConfig(from: jsonURL)
		
		let uptimeDB = try UptimeDB(base:databasePath, logLevel:.debug)
		let coalescer = Coalescer(database: uptimeDB, logLevel: .debug)
		let peerActivityMonitor = PeerActivity()
		
		try await cancelWhenGracefulShutdown {
			_ = try await withThrowingTaskGroup(body: { foo in
				
				var peerInfos:[PeerInfo] = []
				for peer in cfg.peers {
					await peerActivityMonitor.recordTime(peer: peer, time: NIODeadline.now())
					let handshakeSignals = FIFO<HandshakeInfo, Swift.Error>()
					peerInfos.append(PeerInfo(publicKey:peer.publicKey, ipAddress:peer.ipAddress, port: peer.port, internalKeepAlive: .seconds(peer.keepAlive), inboundData: FIFO<ByteBuffer, Swift.Error>(), inboundHandshakeSignal: handshakeSignals))
				}
				let myInterface = try WGInterface<[UInt8]>(staticPrivateKey:myPrivateKey, mtu:1400, initialConfiguration:peerInfos, logLevel:.info, encryptedPacketProcessor: DefaultEPP(), listeningPort: myPort)
				
				for (peer, peerInfo) in zip(cfg.peers, peerInfos) {
					foo.addTask {
						let iterator = peerInfo.inboundHandshakeSignal.makeAsyncConsumer()
						while !Task.isCancelled {
							if let incomingSignal = try await iterator.next(whenTaskCancelled: .finish) {
								await peerActivityMonitor.recordTime(peer: peer, time: NIODeadline.now())
								try await coalescer.record(incomingSignal.recordedTime, key: peerInfo.publicKey, rtt: incomingSignal.rtt)
							}
						}
					}
				}
				
				for peer in cfg.peers {
					foo.addTask {
						cliLogger.info("WireGuard interface started. Waiting for channel initialization...")
						try await myInterface.waitForChannelInit()
						try await myInterface.write(publicKey: peer.publicKey, data: [])
					}
				}
				
				foo.addTask {
					while true {
						let inactivePeers = await peerActivityMonitor.checkInactivity()
						for inactivePeer in inactivePeers {
							try await inactiveNotificationFunc(inactivePeer)
						}
						try await Task.sleep(for: .seconds(20))
					}
				}
				
				try await foo.waitForAll()
			})
		}
	}
}

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the uptime daemon.",
			subcommands: [
				Print.self,
				Slack.self,
				Script.self
			],
			defaultSubcommand: Print.self
		)
		
		struct Print:AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName: "print",
				abstract: "Prints inactivity notifications to the terminal."
			)
			
			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:bedrock.Path = CLI.defaultDBBasePath()

			@Argument(help: "The port number that I am is listening on.")
			var myPort:Int
			@Argument(help:"My private key for the Wireguard interface.")
			var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>

			func run() async throws {
				let logger = Logger(label: "system-uptime-tool")
				let service = MainJournalService(databasePath: databasePath, myPort: myPort, myPrivateKey: myPrivateKey, inactiveNotificationFunc: { inactivePeer in
					logger.info("Inactive Peer Detected!", metadata: ["peerPublicKey":"\(inactivePeer.publicKey)", "notifierPublicKey":"\(PublicKey(privateKey: myPrivateKey))", "ipAddress":"\(inactivePeer.ipAddress)", "port":"\(inactivePeer.port)"])
				})
				try await ServiceGroup(services:[service], logger: logger).run()
			}
		}
		
		struct Slack:AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName: "slack",
				abstract: "Slacks inactivity notifications to the webhook specified in the .env."
			)
			
			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:bedrock.Path = CLI.defaultDBBasePath()

			@Argument(help: "The port number that I am is listening on.")
			var myPort:Int
			@Argument(help:"My private key for the Wireguard interface.")
			var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>

			func run() async throws {
				let logger = Logger(label: "system-uptime-tool")
				let env = try loadEnvFile()
				let service = MainJournalService(databasePath: databasePath, myPort: myPort, myPrivateKey: myPrivateKey, inactiveNotificationFunc: { inactivePeer in
					let response = try await triggerSlackWorkflow(webhookURL: URL(string:env["SLACK_WEBHOOK_URL"]!)!, workflowID: "Wf09QL1QBDS7", inputs: ["peerPublicKey":"\(inactivePeer.publicKey)", "notifierPublicKey":"\(PublicKey(privateKey: myPrivateKey))", "ipAddress":"\(inactivePeer.ipAddress)", "port":"\(inactivePeer.port)"])
					if(response.statusCode != 200) {
						logger.warning("Slack notification failed to send. Check your webhook, workflow, or connection for issues.")
					}
				})
				try await ServiceGroup(services:[service], logger: logger).run()
			}
		}
		
		struct Script:AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName: "script",
				abstract: "Runs a batch script at the specified path when a peer goes inactive."
			)
			
			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:bedrock.Path = CLI.defaultDBBasePath()

			@Argument(help: "The path to the batch script")
			var script:bedrock.Path
			@Argument(help: "The port number that I am is listening on.")
			var myPort:Int
			@Argument(help:"My private key for the Wireguard interface.")
			var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>

			func run() async throws {
				let logger = Logger(label: "system-uptime-tool")
				let service = MainJournalService(databasePath: databasePath, myPort: myPort, myPrivateKey: myPrivateKey, inactiveNotificationFunc: { inactivePeer in
//					let script = Command(absolutePath: SwiftSlash.Path(script.path()), environment: ["PEER_PUBLIC_KEY":"\(inactivePeer.publicKey)", "NOTIFIER_PUBLIC_KEY":"\(PublicKey(privateKey: myPrivateKey))", "IP_ADDRESS":"\(inactivePeer.ipAddress)", "PORT":"\(inactivePeer.port)"])
//					_ = try await script.runSync()
				})
				try await ServiceGroup(services:[service], logger: logger).run()
			}
		}
	}
}
