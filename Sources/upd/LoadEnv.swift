import Foundation

enum EnvError:Error {
	case invalidPath
	case malformedLine
}

func loadEnvFile(
	_ path: URL? = Bundle.module.url(forResource: ".env", withExtension: nil),
	overwrite: Bool = true
) throws -> [String: String] {
	guard let url = path else {
		throw EnvError.invalidPath
	}

	let data = try String(contentsOf: url, encoding: .utf8)

	var env: [String: String] = [:]

	for rawLine in data.split(separator: "\n", omittingEmptySubsequences: false) {
		let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

		if line.isEmpty || line.hasPrefix("#") { continue }

		let parts = line.split(separator: "=", maxSplits: 1)
		guard parts.count == 2 else {
			throw EnvError.malformedLine
		}

		var key   = String(parts[0]).trimmingCharacters(in: .whitespaces)
		var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

		if (value.first == "\"" && value.last == "\"") ||
		   (value.first == "'"  && value.last == "'") {
			value = String(value.dropFirst().dropLast())
		}

		env[key] = value
	}

	return env
}
