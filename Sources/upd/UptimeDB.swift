import QuickLMDB
import RAW
import Logging
import bedrock
import RAW_dh25519
import class Foundation.FileManager

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_fixedwidthinteger_type<UInt64>(bigEndian: true)
@MDB_comparable
public struct NIODate:Sendable, Hashable, Equatable, Comparable { }

@RAW_staticbuff(concat: NIODate.self, PublicKey.self)
@MDB_comparable
public struct UptimeID:Sendable, Hashable, Equatable, Comparable {
	public let date:NIODate
	public let key:PublicKey
}

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_fixedwidthinteger_type<UInt64>(bigEndian: true)
public struct RTT:Sendable, Hashable, Equatable { }

public struct UptimeDB:Sendable {
	private let log:Logger
	private let env:Environment
	private let main:Database.Strict<UptimeID, RTT>
	
	public static func deleteDatabase(base:Path, logLevel:Logger.Level) throws {
		let finalPath = base.appendingPathComponent("system-uptime.mdb")
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		makeLogger.debug("deleting system-uptime database", metadata:["path":"\(finalPath.path())"])
		try FileManager.default.removeItem(atPath:finalPath.path())
		makeLogger.info("successfully deleted system-uptime database")
	}

	public init(base:Path, logLevel:Logger.Level) throws {
		let finalPath = base.appendingPathComponent("system-uptime.mdb")
		let memoryMapSize = size_t(finalPath.getFileSize() + 512 * 1024 * 1024 * 1024) // add 64gb to the file size to allow for growth
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		log = makeLogger
		makeLogger.debug("initializing uptime database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:8, maxDBs:1, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		makeLogger.trace("created environment. now creating initial transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		let newTrans = try Transaction(env:env, readOnly:false)
		makeLogger.trace("created initial transaction. now creating main database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		main = try Database.Strict<UptimeID, RTT>(env:env, name:nil, flags:[.create], tx:newTrans)
		makeLogger.trace("created main database. now committing transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		try newTrans.commit()
	}

	public func scribeNewIncrementValue(date:UptimeID, rtt:RTT, logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"store_date"] = "\(date)"
		logger[metadataKey:"handshake_rtt_value"] = "\(rtt)"
		logger.trace("opening transaction to write data")
		let newTrans = try Transaction(env:env, readOnly:false)
		logger.trace("transaction successfully opened")
		try main.cursor(tx:newTrans) { cursor in
			do {
				let existingDate = try cursor.opLast().key
				guard existingDate < date else {
					logger.error("attempted to write rain data for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
					throw LMDBError.keyExists
				}
			} catch LMDBError.notFound {}
			logger.trace("date validated as incremental. now writing rain value.")
			try cursor.setEntry(key:date, value:increment, flags:[.append])
		}
		try newTrans.commit()
		logger.debug("successfully wrote incremental rain data")
	}

	

	public func listAllRainData(logLevel:Logger.Level) throws -> [UptimeID:RTT] {
		var logger = log
		logger.logLevel = logLevel
		logger.trace("opening transaction to read data")
		let newTrans = try Transaction(env:env, readOnly:true)
		logger.trace("transaction successfully opened")
		var allData:[UptimeID:RTT] = [:]
		main.cursor(tx:newTrans) { cursor in
			logger.trace("cursor successfully opened")
			for (key, value) in cursor {
				logger.trace("found rain data for date \(key) with value \(value)")
				allData[key] = value
			}
		}
		try newTrans.commit()
		return allData
	}
}
