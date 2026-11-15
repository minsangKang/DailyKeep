import Foundation

/// Gemini generateContent REST. 키와 모델명은 Config/Env.xcconfig에서 옵니다.
struct GeminiEnricher: WordEnricher {
    var apiKey = AppConfig.geminiAPIKey
    var model = AppConfig.geminiModel

    static var availabilityDescription: String? {
        AppConfig.geminiAPIKey.isEmpty ? "Config/Env.xcconfig의 GEMINI_API_KEY가 비어 있습니다." : nil
    }

    func enrich(term: String) async throws -> WordInsight {
        guard !apiKey.isEmpty else { throw EnrichError.unavailable(Self.availabilityDescription ?? "") }
        guard let url = URL(string: "\(AppConfig.geminiEndpoint)/\(model):generateContent") else {
            throw EnrichError.unavailable("GEMINI_MODEL 값이 올바르지 않습니다.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: term))

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(GeminiError.self, from: data))?.error.message ?? "HTTP \(status)"
            throw EnrichError.badResponse(message)
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
              let json = text.data(using: .utf8) else {
            throw EnrichError.badResponse("빈 응답")
        }
        return try JSONDecoder().decode(WordInsight.self, from: json)
    }

    static func body(for term: String) -> [String: Any] {
        let string: [String: Any] = ["type": "STRING"]
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "meaning": string,
                "partOfSpeech": string,
                "pronunciation": string,
                "examples": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": ["sentence": string, "translation": string],
                        "required": ["sentence", "translation"],
                    ] as [String: Any],
                ] as [String: Any],
                "synonyms": ["type": "ARRAY", "items": string] as [String: Any],
                "usageNote": string,
            ] as [String: Any],
            "required": ["meaning", "partOfSpeech", "pronunciation", "examples", "synonyms", "usageNote"],
        ]
        return [
            "systemInstruction": ["parts": [["text": WordPrompt.instructions]]],
            "contents": [["role": "user", "parts": [["text": WordPrompt.make(for: term)]]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": schema] as [String: Any],
        ]
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
    let candidates: [Candidate]?
}

private struct GeminiError: Decodable {
    struct Body: Decodable { let message: String }
    let error: Body
}
