import Foundation

// MARK: - Compact Format DTOs

/// A single food item from the compact endpoint
struct CompactFood: Decodable, Sendable {
    let id: String
    let foodGroupId: String
    let url: String
    let foodName: String
    let energyKj: Int?
    let energyKcal: Int?
    let ediblePart: Int?
    let constituents: [String: CompactConstituent]?
}

struct CompactConstituent: Decodable, Sendable {
    let quantity: [ConstituentValue]?

    enum ConstituentValue: Decodable, Sendable {
        case number(Double)
        case string(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let d = try? container.decode(Double.self) {
                self = .number(d)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else {
                self = .number(0)
            }
        }
    }
}

// MARK: - Full Format DTOs (kept for search index + food group lookups)

struct MatvaretabellenResponse: Decodable, Sendable {
    let foods: [MatvaretabellenFood]
}

struct MatvaretabellenFood: Decodable, Sendable {
    let foodId: String
    let foodName: String
    let foodGroupId: String
    let calories: MatvaretabellenEnergy?
    let energy: MatvaretabellenEnergy?
    let portions: [MatvaretabellenPortion]?
    let ediblePart: MatvaretabellenEdiblePart?
    let constituents: [MatvaretabellenConstituent]?
    let latinName: String?
    let searchKeywords: [String]?
}

struct MatvaretabellenEnergy: Decodable, Sendable {
    let quantity: Double?
    let unit: String
}

struct MatvaretabellenPortion: Decodable, Sendable {
    let portionName: String
    let portionUnit: String
    let quantity: Double
    let unit: String
}

struct MatvaretabellenEdiblePart: Decodable, Sendable {
    let percent: Int
}

struct MatvaretabellenConstituent: Decodable, Sendable {
    let nutrientId: String
    let quantity: Double?
    let unit: String?
}

struct MatvaretabellenFoodGroup: Decodable, Sendable {
    let foodGroupId: String
    let name: String
    let parentId: String?
}

// MARK: - Search Index DTO

struct MatvaretabellenSearchIndex: Decodable, Sendable {
    let foodName: [String: [String: Int]]
    let foodNameEdgegrams: [String: [String: Int]]
}

// MARK: - Service

actor MatvaretabellenService {
    static let shared = MatvaretabellenService()

    private let session: URLSession

    // Cached data
    private var cachedCompactFoods: [CompactFood]?
    private var compactFoodsById: [String: CompactFood]?
    private var cachedFoodGroups: [MatvaretabellenFoodGroup]?
    private var foodGroupsById: [String: MatvaretabellenFoodGroup]?
    private var cachedSearchIndex: MatvaretabellenSearchIndex?
    private var cacheTimestamp: Date?
    private static let cacheDuration: TimeInterval = 3600

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Compact Foods

    /// Fetch all foods from the compact endpoint (~4.6MB, ~200KB gzipped)
    func fetchCompactFoods() async throws -> [CompactFood] {
        if let cached = cachedCompactFoods,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < Self.cacheDuration {
            return cached
        }

        guard let url = URL(string: Constants.API.matvaretabellenCompactFoodsURL) else {
            throw MatvaretabellenError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MatvaretabellenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MatvaretabellenError.httpError(httpResponse.statusCode)
        }

        let foods = try JSONDecoder().decode([CompactFood].self, from: data)
        cachedCompactFoods = foods
        compactFoodsById = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        cacheTimestamp = Date()
        return foods
    }

    /// Get a compact food by its ID
    func getCompactFood(id: String) async throws -> CompactFood? {
        if let cached = compactFoodsById {
            return cached[id]
        }
        let foods = try await fetchCompactFoods()
        let lookup = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        compactFoodsById = lookup
        return lookup[id]
    }

    // MARK: - Food Groups

    func fetchFoodGroups() async throws -> [MatvaretabellenFoodGroup] {
        if let cached = cachedFoodGroups {
            return cached
        }

        guard let url = URL(string: Constants.API.matvaretabellenFoodGroupsURL) else {
            throw MatvaretabellenError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MatvaretabellenError.invalidResponse
        }

        let groups = try JSONDecoder().decode([MatvaretabellenFoodGroup].self, from: data)
        cachedFoodGroups = groups
        foodGroupsById = Dictionary(groups.map { ($0.foodGroupId, $0) }, uniquingKeysWith: { _, last in last })
        return groups
    }

    /// Resolve a food group ID to its display name
    func foodGroupName(for id: String) async throws -> String? {
        if foodGroupsById == nil {
            _ = try await fetchFoodGroups()
        }
        return foodGroupsById?[id]?.name
    }

    // MARK: - Search Index

    func fetchSearchIndex() async throws -> MatvaretabellenSearchIndex {
        if let cached = cachedSearchIndex {
            return cached
        }

        guard let url = URL(string: Constants.API.matvaretabellenSearchIndexURL) else {
            throw MatvaretabellenError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MatvaretabellenError.invalidResponse
        }

        let index = try JSONDecoder().decode(MatvaretabellenSearchIndex.self, from: data)
        cachedSearchIndex = index
        return index
    }

    func searchFoodIds(query: String, limit: Int = 30) async throws -> [String] {
        let index = try await fetchSearchIndex()
        let lowered = query.lowercased()
        let tokens = lowered.split(separator: " ").map(String.init)

        var scores: [String: Int] = [:]

        for token in tokens {
            if let foodIds = index.foodName[token] {
                for (foodId, score) in foodIds {
                    scores[foodId, default: 0] += score * 10
                }
            }

            for (edgegram, foodIds) in index.foodNameEdgegrams {
                if edgegram.hasPrefix(token) || token.hasPrefix(edgegram) {
                    for (foodId, score) in foodIds {
                        scores[foodId, default: 0] += score
                    }
                }
            }
        }

        let ranked = scores.sorted { $0.value > $1.value }
        return Array(ranked.prefix(limit).map(\.key))
    }

    func searchFoods(query: String, limit: Int = 30) async throws -> [CompactFood] {
        let matchingIds = try await searchFoodIds(query: query, limit: limit)
        guard !matchingIds.isEmpty else { return [] }

        if compactFoodsById == nil {
            _ = try await fetchCompactFoods()
        }

        guard let lookup = compactFoodsById else { return [] }
        return matchingIds.compactMap { lookup[$0] }
    }
}

// MARK: - Compact Food Helpers

extension CompactFood {
    func nutrientQuantity(for id: String) -> Double? {
        guard let constituent = constituents?[id],
              let quantity = constituent.quantity,
              let first = quantity.first else {
            return nil
        }
        switch first {
        case .number(let value): return value
        case .string: return nil
        }
    }

    var kcal: Double { Double(energyKcal ?? 0) }
    var protein: Double { nutrientQuantity(for: "Protein") ?? 0 }
    var carbs: Double { nutrientQuantity(for: "Karbo") ?? 0 }
    var fat: Double { nutrientQuantity(for: "Fett") ?? 0 }
    var fiber: Double? { nutrientQuantity(for: "Fiber") }
    var saturatedFat: Double? { nutrientQuantity(for: "Mettet") }
    var monounsaturatedFat: Double? { nutrientQuantity(for: "Enumet") }
    var polyunsaturatedFat: Double? { nutrientQuantity(for: "Flerum") }
    var transFat: Double? { nutrientQuantity(for: "Trans") }
    var omega3: Double? { nutrientQuantity(for: "Omega-3") }
    var omega6: Double? { nutrientQuantity(for: "Omega-6") }
    var cholesterol: Double? { nutrientQuantity(for: "Kolest") }
    var sugar: Double? { nutrientQuantity(for: "Mono+Di") }
    var addedSugar: Double? { nutrientQuantity(for: "Sukker") }
    var starch: Double? { nutrientQuantity(for: "Stivel") }
    var salt: Double? { nutrientQuantity(for: "NaCl") }
    var water: Double? { nutrientQuantity(for: "Vann") }

    // Vitamins
    var vitaminA: Double? { nutrientQuantity(for: "Vit A") }
    var vitaminD: Double? { nutrientQuantity(for: "Vit D") }
    var vitaminE: Double? { nutrientQuantity(for: "Vit E") }
    var vitaminC: Double? { nutrientQuantity(for: "Vit C") }
    var vitaminB1: Double? { nutrientQuantity(for: "Vit B1") }
    var vitaminB2: Double? { nutrientQuantity(for: "Vit B2") }
    var vitaminB6: Double? { nutrientQuantity(for: "Vit B6") }
    var vitaminB12: Double? { nutrientQuantity(for: "Vit B12") }
    var niacin: Double? { nutrientQuantity(for: "Niacin") }
    var folate: Double? { nutrientQuantity(for: "Folat") }

    // Minerals
    var calcium: Double? { nutrientQuantity(for: "Ca") }
    var iron: Double? { nutrientQuantity(for: "Fe") }
    var magnesium: Double? { nutrientQuantity(for: "Mg") }
    var potassium: Double? { nutrientQuantity(for: "K") }
    var sodium: Double? { nutrientQuantity(for: "Na") }
    var zinc: Double? { nutrientQuantity(for: "Zn") }
    var selenium: Double? { nutrientQuantity(for: "Se") }
    var phosphorus: Double? { nutrientQuantity(for: "P") }
    var copper: Double? { nutrientQuantity(for: "Cu") }
    var iodine: Double? { nutrientQuantity(for: "I") }
}

// MARK: - Errors

enum MatvaretabellenError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Matvaretabellen API URL"
        case .invalidResponse:
            return "Invalid response from Matvaretabellen API"
        case .httpError(let code):
            return "Matvaretabellen API returned status \(code)"
        }
    }
}
