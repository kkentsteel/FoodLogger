import Foundation

actor FoodParsingService {
    private let claudeAPI = ClaudeAPIService()

    struct ParsedFoodItem: Codable, Sendable, Identifiable {
        let id: UUID
        let name: String
        let estimatedCalories: Double
        let estimatedProtein: Double
        let estimatedCarbs: Double
        let estimatedFat: Double
        let estimatedServingSize: String
        var quantity: Double
    }

    func parseFoodDescription(_ text: String, apiKey: String) async throws -> [ParsedFoodItem] {
        let systemPrompt = """
        You are a food nutrition parser. The user will describe what they ate in natural language. \
        Parse it into individual food items with estimated nutrition per serving.

        RESPOND ONLY with a JSON array. No other text, no markdown fences, no explanation.
        Each object must have these exact fields:
        - "name": string (food name, capitalize first letter)
        - "estimatedCalories": number (kcal per serving)
        - "estimatedProtein": number (grams per serving)
        - "estimatedCarbs": number (grams per serving)
        - "estimatedFat": number (grams per serving)
        - "estimatedServingSize": string (e.g. "1 taco", "100g", "1 cup")
        - "quantity": number (how many servings the user had)

        Be accurate with common food nutrition estimates. When in doubt, use standard portion sizes.
        """

        let messages = [ClaudeMessage(role: "user", content: text)]
        let response = try await claudeAPI.sendMessage(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            messages: messages
        )

        // Clean response: strip markdown fences if present
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw FoodParsingError.invalidResponse
        }

        struct RawItem: Codable {
            let name: String
            let estimatedCalories: Double
            let estimatedProtein: Double
            let estimatedCarbs: Double
            let estimatedFat: Double
            let estimatedServingSize: String
            let quantity: Double
        }

        let raw = try JSONDecoder().decode([RawItem].self, from: data)

        return raw.map { item in
            ParsedFoodItem(
                id: UUID(),
                name: item.name,
                estimatedCalories: item.estimatedCalories,
                estimatedProtein: item.estimatedProtein,
                estimatedCarbs: item.estimatedCarbs,
                estimatedFat: item.estimatedFat,
                estimatedServingSize: item.estimatedServingSize,
                quantity: item.quantity
            )
        }
    }
}

enum FoodParsingError: LocalizedError {
    case invalidResponse
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Could not parse food items from AI response. Try rephrasing."
        case .noAPIKey: return "No API key configured. Add your Claude API key in Settings."
        }
    }
}
