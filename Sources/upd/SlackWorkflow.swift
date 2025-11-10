// MacOS
import Foundation
// Linux
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

		let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
		var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

		if (value.first == "\"" && value.last == "\"") ||
		   (value.first == "'"  && value.last == "'") {
			value = String(value.dropFirst().dropLast())
		}

		env[key] = value
	}
	return env
}

@discardableResult
func triggerSlackWorkflow(
	webhookURL: URL,
	workflowID: String,
	inputs: [String: Any] = [:]
) async throws -> HTTPURLResponse {
	let jsonData = try JSONSerialization.data(withJSONObject: inputs, options: [])

	var request = URLRequest(url: webhookURL)
	request.httpMethod = "POST"
	request.setValue("application/json; charset=utf-8",
					 forHTTPHeaderField: "Content-Type")
	request.httpBody = jsonData

	let (_, response) = try await URLSession.shared.data(for: request)

	guard let httpResponse = response as? HTTPURLResponse else {
		throw NSError(domain: "SlackWebhookError",
					  code: 0,
					  userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
	}
	return httpResponse
}
