import ArgumentParser
import class Foundation.FileManager
import bedrock
import Logging
import struct QuickLMDB.Transaction

@main
struct CLI:AsyncParsableCommand {
	static func defaultDBBasePath() -> Path {
		return Path(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("weatherboi_lmdb").path)
	}

	static let configuration = CommandConfiguration(
		commandName:"uptime-daemon",
		abstract:"a highly efficient daemon for capturing, storing, and redistributing data from on-premises weather stations.",
//		version:"\(GitRepositoryInfo.tag) (\(GitRepositoryInfo.commitHash))\(GitRepositoryInfo.commitRevisionHash != nil ? " commit revision: \(GitRepositoryInfo.commitRevisionHash!.prefix(8))" : "")",
		subcommands:[
			Run.self,
			Uptime.self
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
				abstract:"a subcommand for clearing rain data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"system-uptime.clear")
//				let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
//				try RainDB.deleteDatabase(base:homeDirectory, logLevel:.trace)
//				let metaDB = try MetadataDB(base:homeDirectory, logLevel:.trace)
//				try metaDB.clearCumulativeRainValue(logLevel:.trace)
				logger.info("successfully cleared rain database")
			}
		}

		struct List:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"list",
				abstract:"a subcommand for listing rain data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.list")
//				let rainDB = try RainDB(base:databasePath, logLevel:.trace)
//				let allData = try rainDB.listAllRainData(logLevel:.debug)
//				var sumValue:Double = 0
//				for (date, value) in allData.sorted(by: { $0.key < $1.key }) {
//					logger.info("rain data for \(date): \(value)")
//					sumValue += Double(value)
//				}
//				logger.info("total rain data: \(UInt32(sumValue))")
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
