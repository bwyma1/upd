import Foundation

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

	// Slack responds with 200 OK for success.  If you want, you can
	// inspect the body (`{ "ok": true }`) for extra safety.
	return httpResponse
}
