import ArgumentParser
import Foundation
import bedrock
import Logging
import RAW_dh25519
import struct QuickLMDB.Transaction
import Configuration

@main
struct CLI:AsyncParsableCommand {
	static func defaultDBBasePath() -> Path {
		return Path(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("upd_lmdb").path)
	}

	static let configuration = CommandConfiguration(
		commandName:"uptime-daemon",
		abstract:"a simple daemon for capturing, storing, and signaling uptime information about a system.",
		subcommands:[
			Run.self,
			Uptime.self,
			Config.self
		]
	)

	struct Uptime:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName:"uptime",
			abstract:"a subcommand for sytem uptime related operations.",
			subcommands:[
				List.self,
				Clear.self
			]
		)

		struct Clear:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"clear",
				abstract:"a subcommand for clearing uptime data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"system-uptime.clear")
				let uptimeDB = try UptimeDB(base:databasePath, logLevel:.debug)
				try uptimeDB.clearDatabase()
				logger.info("successfully cleared rain database")
			}
		}

		struct List:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"list",
				abstract:"a subcommand for listing system uptime data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"system-uptime.list")
				let uptimeDB = try UptimeDB(base:databasePath, logLevel:.debug)
				let allData = try uptimeDB.listAllSystemUptimeData(logLevel: .debug)
				let formatter = DateFormatter()
				formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
				for (uptime, rtt) in allData.sorted(by: { $0.key < $1.key }) {
					logger.info("Handshake Date: \(formatter.string(from: dateFromNIOUInt64(uptime.date.RAW_native()))) RTT: \(rtt.RAW_native() / 1_000_000) ms", metadata: ["public-key":"\(String(describing:uptime.key))"])
				}
			}
		}
	}
}


extension Path:@retroactive ExpressibleByArgument {
	public init?(argument:String) {
		self.init(argument)
	}
	public var description:String {
		return self.path()
	}
}
