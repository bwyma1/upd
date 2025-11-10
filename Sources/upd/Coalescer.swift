import Logging
import RAW_dh25519
import NIO

actor Coalescer {
	private var handshakes: [(time:NIODeadline, key:PublicKey, rtt:NIODeadline)] = []
	private var coalescingTask: Task<Void, any Error>? = nil
	private let interval: Duration = .seconds(1)
	private let uptimeDB:UptimeDB
	private var log:Logger
	
	init(database:UptimeDB, logLevel:Logger.Level) {
		uptimeDB = database
		log = Logger(label:"\(String(describing:Self.self))")
		log.logLevel = logLevel
	}

	/// Called by peers to report their deadline.
	func record(_ deadline: NIODeadline, key:PublicKey, rtt:NIODeadline) throws {
		handshakes.append((deadline, key, rtt))

		if coalescingTask == nil {
			coalescingTask = Task { [weak self] in
				guard let self = self else { return }
				try await Task.sleep(for: self.interval)
				try await self.processWindow()
			}
		}
	}

	/// Called after the 1-second window closes.
	private func processWindow() throws {
		defer {
			handshakes.removeAll()
			coalescingTask = nil
		}

		let sortedHandshakes = handshakes.sorted {
			let t1 = $0.time.uptimeNanoseconds
			let t2 = $1.time.uptimeNanoseconds
			if t1 == t2 {
				return $0.key < $1.key
			}
			return t1 < t2
		}
		for handshake in sortedHandshakes {
			let uptime = UptimeID(deadline: handshake.time, key: handshake.key)
			Task {
				try uptimeDB.scribeNewHandshakeValue(date: uptime, rtt: RTT(RAW_native:handshake.rtt.uptimeNanoseconds), logLevel: log.logLevel)
			}
		}
	}
}
