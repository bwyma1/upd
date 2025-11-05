import RAW
import RAW_dh25519
import RAW_base64
import ArgumentParser
import bedrock_ip

enum InactiveAction: String, CaseIterable, ExpressibleByArgument {
	case print
	case slack
	case script

	var help: String {
		switch self {
			case .print: return "Print inactive peer to the console."
			case .slack: return "Send a message of the inactive peer to the designated Slack webhook in the .env file."
			case .script: return "Execute an external batch script."
		}
	}
}

extension RAW_dh25519.PublicKey:@retroactive ExpressibleByArgument {
	public init?(argument: String) {
		let rawBytes = try? RAW_base64.decode(argument)
		guard let bytes = rawBytes, bytes.count == 32 else {
			return nil
		}
		self = RAW_dh25519.PublicKey(RAW_staticbuff:bytes)
	}
}

extension MemoryGuarded<RAW_dh25519.PrivateKey>:@retroactive ExpressibleByArgument {
	public convenience init?(argument: String) {
		let rawBytes = try? RAW_base64.decode(argument)
		guard let bytes = rawBytes, bytes.count == 32 else {
			return nil
		}
		self.init(RAW_decode:bytes, count:32)
	}
}
