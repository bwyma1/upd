import NIO
import Foundation

// Used for logs and listing uptime statistics
func dateFromNIOUInt64(_ nsValue: UInt64) -> Date {
	let nowDeadline = NIODeadline.now()
	let nowNano = nowDeadline.uptimeNanoseconds
	
	let deltaNano = Int64(nsValue) - Int64(nowNano)
	
	let deltaSeconds = Double(deltaNano) / 1_000_000_000
	
	return Date().addingTimeInterval(deltaSeconds)
}
