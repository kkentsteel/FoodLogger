import Foundation

enum Constants {
    enum Keychain {
        static let claudeAPIKey = "claude_api_key"
    }

    enum API {
        static let claudeEndpoint = "https://api.anthropic.com/v1/messages"
        static let claudeModel = "claude-sonnet-4-20250514"
        static let claudeVersion = "2023-06-01"
        static let claudeMaxTokens = 4096

        static let offBaseURL = "https://world.openfoodfacts.org/api/v2/product"
        static let offUserAgent = "FoodLogger/1.0"

        static let matvaretabellenCompactFoodsURL = "https://www.matvaretabellen.no/api/nb/compact-foods.json"
        static let matvaretabellenFoodsURL = "https://www.matvaretabellen.no/api/nb/foods.json"
        static let matvaretabellenFoodGroupsURL = "https://www.matvaretabellen.no/api/nb/food-groups.json"
        static let matvaretabellenSearchIndexURL = "https://www.matvaretabellen.no/search/index/nb.json"
    }

    enum Defaults {
        static let defaultMealSlots: [(name: String, icon: String)] = [
            ("Breakfast", "sunrise"),
            ("Lunch", "sun.max"),
            ("Dinner", "sunset"),
            ("Snack", "cup.and.saucer")
        ]
        static let defaultCalorieTarget = 2000
        static let searchDebounceMilliseconds = 300
    }
}
