import ArgumentParser
import NIO
import ServiceLifecycle
import Foundation
import Logging
import bedrock
import bedrock_fifo
import RAW_dh25519
import RAW_base64
import RAW
import wireguard_userspace_nio

struct MainJournalService:Service {
	var databasePath:Path = CLI.defaultDBBasePath()
	var myPort:Int
	var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>
	func run() async throws {
		var tempLogger = Logger(label: "system-uptime-tool")
		tempLogger.logLevel = .debug
		let cliLogger = tempLogger
		
		let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
		let jsonURL = URL(fileURLWithPath: homeDirectory.appendingPathComponent("peer-config.json").path())
		let cfg = try loadConfig(from: jsonURL)
		
		let uptimeDB = try UptimeDB(base:databasePath, logLevel:.debug)
		let coalescer = Coalescer(database: uptimeDB, logLevel: .debug)
		try await cancelWhenGracefulShutdown {
			_ = try await withThrowingTaskGroup(body: { foo in
				var myPeers:[PeerInfo] = []
				for peer in cfg.peers {
					let handshakeSignals = FIFO<HandshakeInfo, Swift.Error>()
					myPeers.append(PeerInfo(publicKey:peer.publicKey, ipAddress:peer.ipAddress, port: peer.port, internalKeepAlive: .seconds(peer.keepAlive), inboundData: FIFO<ByteBuffer, Swift.Error>(), inboundHandshakeSignal: handshakeSignals))
				}
				let myInterface = try WGInterface<[UInt8]>(staticPrivateKey:myPrivateKey, mtu:1400, initialConfiguration:myPeers, logLevel:.critical, encryptedPacketProcessor: DefaultEPP(), listeningPort: myPort)
				
				for peerInfo in myPeers {
					foo.addTask {
						let iterator = peerInfo.inboundHandshakeSignal.makeAsyncConsumer()
						while !Task.isCancelled {
							if let incomingSignal = try await iterator.next(whenTaskCancelled: .finish) {
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
				
				try await foo.waitForAll()
			})
		}
	}
}

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the weatherboi server."
		)

		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:Path = CLI.defaultDBBasePath()

		@Argument(help: "The port number that the I am is listening on.")
		var myPort:Int
		@Argument(help:"The private key that the initiator will use to forge an initial handshake.")
		var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>

		func run() async throws {
			let logger = Logger(label: "system-uptime-tool")
			let service = MainJournalService(databasePath: databasePath, myPort: myPort, myPrivateKey: myPrivateKey)
			try await ServiceGroup(services:[service], logger: logger).run()
		}
	}
}
