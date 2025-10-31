import ArgumentParser
import NIO
import ServiceLifecycle
import Logging
import bedrock
import bedrock_fifo
import RAW_dh25519
import RAW_base64
import RAW
import wireguard_userspace_nio

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the weatherboi server."
		)

		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:Path = CLI.defaultDBBasePath()

		@Argument(help: "The IP address of the responder.")
		var ipAddress:String
		@Argument(help: "The port number that the I am is listening on.")
		var myPort:Int
		@Argument(help:"The private key that the initiator will use to forge an initial handshake.")
		var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>
		@Argument(help:"The port and public key that the responder is expected to be operating with.")
		var peers:[Peer]

		func run() async throws {
			var cliLogger = Logger(label: "wg-test-tool.initiator")
			cliLogger.logLevel = .debug
			
			let uptimeDB = try UptimeDB(base:databasePath, logLevel:.debug)
			_ = try await withThrowingTaskGroup(body: { foo in
				var myPeers:[PeerInfo] = []
				for peer in peers {
					var handshakeSignals = FIFO<NIODeadline, Swift.Error>()
					myPeers.append(PeerInfo(publicKey:peer.publicKey, ipAddress:ipAddress, port: peer.port, internalKeepAlive: .seconds(30), inboundData: FIFO<ByteBuffer, Swift.Error>(), inboundHandshakeSignal: handshakeSignals))
				}
				let myInterface = try WGInterface<[UInt8]>(staticPrivateKey:myPrivateKey, mtu:1400, initialConfiguration:myPeers, logLevel:.info, encryptedPacketProcessor: DefaultEPP(), listeningPort: myPort)
				
				foo.addTask {
					try await myInterface.run()
				}
				
				cliLogger.info("WireGuard interface started. Waiting for channel initialization...")
				try await myInterface.waitForChannelInit()
				
				for peerInfo in myPeers {
					foo.addTask {
						let iterator = peerInfo.inboundHandshakeSignal.makeAsyncConsumer()
						while(true) {
							if let incomingSignal = try await iterator.next() {
								// add info to database
							}
						}
					}
				}
				
				try await Task.sleep(for: .seconds(100000))
			})
		}
	}
}
