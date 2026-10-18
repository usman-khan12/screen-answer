import Foundation

enum OpenAIError: LocalizedError {
    case missingKey
    case api(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No OpenAI API key. Add one in Settings (menu bar icon → Settings…)."
        case .api(let message): return message
        case .emptyResponse: return "The model returned no text."
        }
    }
}

/// Minimal client for OpenAI's Responses API with an image input.
enum OpenAIClient {
    static func ask(prompt: String, imageJPEG: Data, model: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenAIError.missingKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let imageURL = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let body: [String: Any] = [
            "model": model,
            "input": [[
                "role": "user",
                "content": [
                    ["type": "input_text", "text": prompt],
                    ["type": "input_image", "image_url": imageURL, "detail": "high"],
                ],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = (json?["error"] as? [String: Any])?["message"] as? String
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.api("OpenAI error \(http.statusCode): \(message)")
        }

        // Collect every output_text chunk from message items in the response.
        let output = json?["output"] as? [[String: Any]] ?? []
        let text = output
            .filter { $0["type"] as? String == "message" }
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .filter { $0["type"] as? String == "output_text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw OpenAIError.emptyResponse }
        return text
    }
}
