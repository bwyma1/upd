import QuickLMDB
import RAW
import Logging
import bedrock
import RAW_dh25519
import NIO
import class Foundation.DateFormatter
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
	
	init(date:NIODate, key:PublicKey) {
		self.date = date
		self.key = key
	}
	init(deadline:NIODeadline, key:PublicKey) {
		self.date = NIODate(RAW_native: deadline.uptimeNanoseconds)
		self.key = key
	}
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
		var log = Logger(label:"\(String(describing:Self.self))")
		log.logLevel = logLevel
		self.log = log
		log.debug("initializing uptime database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:8, maxDBs:1, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		log.trace("created environment. now creating initial transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		let newTrans = try Transaction(env:env, readOnly:false)
		log.trace("created initial transaction. now creating main database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		main = try Database.Strict<UptimeID, RTT>(env:env, name:nil, flags:[.create], tx:newTrans)
		log.trace("created main database. now committing transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		try newTrans.commit()
	}
	
	public func clearDatabase() throws {
		let newTrans = try Transaction(env: env, readOnly: false)
		try main.deleteAllEntries(tx: newTrans)
		try newTrans.commit()
		log.info("successfully deleted system-uptime database")
	}

	public func scribeNewHandshakeValue(date:UptimeID, rtt:RTT, logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		logger[metadataKey:"store_date"] = "\(formatter.string(from: dateFromNIOUInt64(date.date.RAW_native())))"
		logger[metadataKey:"handshake_rtt_value"] = "\(rtt.RAW_native() / 1_000_000) ms"
		logger.trace("opening transaction to write data")
		let newTrans = try Transaction(env:env, readOnly:false)
		logger.trace("transaction successfully opened")
		try main.cursor(tx:newTrans) { cursor in
			do {
				let existingDate = try cursor.opLast().key
				guard existingDate < date else {
					logger.error("attempted to write system uptime data for a date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
					throw LMDBError.keyExists
				}
			} catch LMDBError.notFound {}
			logger.trace("date validated as incremental. now writing rtt value.")
			try cursor.setEntry(key:date, value:rtt, flags:[.append])
		}
		try newTrans.commit()
		logger.debug("successfully wrote incremental uptime data")
	}

	

	public func listAllSystemUptimeData(logLevel:Logger.Level) throws -> [UptimeID:RTT] {
		var logger = log
		logger.logLevel = logLevel
		logger.trace("opening transaction to read data")
		let newTrans = try Transaction(env:env, readOnly:true)
		logger.trace("transaction successfully opened")
		var allData:[UptimeID:RTT] = [:]
		main.cursor(tx:newTrans) { cursor in
			logger.trace("cursor successfully opened")
			for (key, value) in cursor {
				logger.trace("found uptime data for date \(key) with value \(value)")
				allData[key] = value
			}
		}
		try newTrans.commit()
		return allData
	}
}
