import Foundation

class FeatherlessService {
    static let baseURL = "https://api.featherless.ai/v1/chat/completions"
    static let model = "meta-llama/Meta-Llama-3.1-8B-Instruct"

    // This private helper pulls the key from your Property List
    private static var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["FEATHERLESS_API_KEY"] as? String else {
            // If this triggers, check that Secrets.plist exists and the key name is exact
            print("ERROR: FEATHERLESS_API_KEY not found in Secrets.plist")
            return ""
        }
        return key
    }

    static func generate(prompt: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 512,
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use the dynamic apiKey property
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Featherless HTTP Status: \(httpResponse.statusCode)")
        }
        
        if let raw = String(data: data, encoding: .utf8) {
            print("Featherless Raw Response: \(raw)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        // Handle API-side errors
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw NSError(domain: "FeatherlessAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            throw URLError(.cannotParseResponse)
        }

        return text
    }
}
