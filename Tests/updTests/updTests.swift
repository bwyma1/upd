import Testing
import Foundation
import SystemPackage
import RAW_dh25519
import RAW_base64
import RAW
@testable import upd
import bedrock
import Configuration

@Suite("Uptime Daemon Tests", .serialized)
struct UptimeDaemonTests {}

extension UptimeDaemonTests {
	@Suite("upd Configuration Tests",
		   .serialized
	)
	struct ConfigurationTests {
		
		let privateKeyA = MemoryGuarded<PrivateKey>(RAW_decode:try! RAW_base64.decode("8DFnI7tPWLl4WmuEp4T5KVuKMW6iyjRdTb3IVaDe+kI="), count:32)!
		let privateKeyB = MemoryGuarded<PrivateKey>(RAW_decode:try! RAW_base64.decode("SD/y8yQa/DgiYRnDI9vJEiGezNn4yLd/4yL9OLnej0A="), count:32)!
		let testURL = URL(fileURLWithPath: Path(FileManager.default.homeDirectoryForCurrentUser.path).appendingPathComponent("test-config.json").path())
		
		init() {
			do {
				try FileManager.default.removeItem(at: testURL)
			} catch {}
		}
		
		@Test func testLoadNonExistentConfig() throws {
			let appConfig = try loadConfig(from: testURL)
			#expect(appConfig.peers == [])
			try FileManager.default.removeItem(at: testURL)
		}
		
		@Test func testWritingToConfig() throws {
			var appConfig = AppConfig()
			let newPeerA = Peer(publicKey: PublicKey(privateKey: privateKeyA), ipAddress: "127.0.0.1", port: 8080, keepAlive: 25)
			let newPeerB = Peer(publicKey: PublicKey(privateKey: privateKeyB), ipAddress: "127.0.0.2", port: 9021, keepAlive: 30)
			appConfig.peers.append(newPeerA)
			appConfig.peers.append(newPeerB)
			
			try writeConfig(appConfig, to: testURL)
			var jsonString = try String(contentsOf: testURL, encoding: .utf8)
			jsonString = jsonString
					.replacingOccurrences(of: "\n", with: "")
					.replacingOccurrences(of: "\r", with: "")
					.replacingOccurrences(of: "\t", with: "")
					.replacingOccurrences(of: " ", with: "")
			let expectedJsonString = "{\"peers\":[{\"keepAlive\":25,\"port\":8080,\"publicKey\":{\"key\":\"nECVAdGyyGyqrs8HIZpY3JibiSRUj984OajCG52z0gM=\"}},{\"keepAlive\":30,\"port\":9021,\"publicKey\":{\"key\":\"L5MhmJc+WhIV4u4LZ7rHdSZxwIWFCQgioIbI\\/bVdA0I=\"}}]}"
			#expect(jsonString == expectedJsonString)
			try FileManager.default.removeItem(at: testURL)
		}
		
		@Test func testReadingFromConfig() throws {
			var appConfig = AppConfig()
			let newPeerA = Peer(publicKey: PublicKey(privateKey: privateKeyA), ipAddress: "127.0.0.1", port: 8080, keepAlive: 25)
			let newPeerB = Peer(publicKey: PublicKey(privateKey: privateKeyB), ipAddress: "127.0.0.2", port: 9021, keepAlive: 30)
			appConfig.peers.append(newPeerA)
			appConfig.peers.append(newPeerB)
			
			try writeConfig(appConfig, to: testURL)
			
			let readAppConfig = try loadConfig(from: testURL)
			#expect(appConfig.peers == readAppConfig.peers)
			try FileManager.default.removeItem(at: testURL)
		}
		
		@Test func testModifyConfig() throws {
			var appConfig = AppConfig()
			let newPeerA = Peer(publicKey: PublicKey(privateKey: privateKeyA), ipAddress: "127.0.0.1", port: 8080, keepAlive: 25)
			let newPeerB = Peer(publicKey: PublicKey(privateKey: privateKeyB), ipAddress: "127.0.0.2", port: 9021, keepAlive: 30)
			appConfig.peers.append(newPeerA)
			
			try writeConfig(appConfig, to: testURL)
			
			try editConfig(at: testURL) { cfg in
				cfg.peers.append(newPeerB)
			}
			
			appConfig.peers.append(newPeerB)
			#expect(try loadConfig(from: testURL).peers == appConfig.peers)
			try FileManager.default.removeItem(at: testURL)
		}
	}
}

@Test func slackMessage() async throws {
	let env = try loadEnvFile()
	let response = try await triggerSlackWorkflow(webhookURL: URL(string:env["SLACK_WEBHOOK_URL"]!)!, workflowID: "Wf09QL1QBDS7", inputs: ["peerPublicKey":"Example Peer Public Key", "notifierPublicKey":"Example Notifier Public Key", "ipAddress":"Example IP Address", "port":"Example port"])
}

@Test func example() async throws {
	let privateKeyA = MemoryGuarded<PrivateKey>(RAW_decode:try! RAW_base64.decode("8DFnI7tPWLl4WmuEp4T5KVuKMW6iyjRdTb3IVaDe+kI="), count:32)!
	let privateKeyB = MemoryGuarded<PrivateKey>(RAW_decode:try! RAW_base64.decode("SD/y8yQa/DgiYRnDI9vJEiGezNn4yLd/4yL9OLnej0A="), count:32)!
	
	let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
	let jsonPath = homeDirectory.appendingPathComponent("peer-config.json")
	
	let fileManager = FileManager.default
	if !fileManager.fileExists(atPath: jsonPath.path()) {
		let emptyJSONData = "{}".data(using: .utf8)!
		fileManager.createFile(atPath: jsonPath.path(), contents: emptyJSONData)
	}
	var appConfig = AppConfig()
	let newPeerA = Peer(publicKey: PublicKey(privateKey: privateKeyA), ipAddress: "127.0.0.1", port: 8080, keepAlive: 25)
	let newPeerB = Peer(publicKey: PublicKey(privateKey: privateKeyB), ipAddress: "127.0.0.2", port: 9021, keepAlive: 30)
	appConfig.peers.append(newPeerA)
	appConfig.peers.append(newPeerB)
	
	let dataURL = URL(fileURLWithPath: jsonPath.path())
	do {
		try writeConfig(appConfig, to: dataURL)
		print("Config written.")
	} catch {
		print("Failed to write config: \(error)")
	}
	
	appConfig = try loadConfig(from: dataURL)
}
