import Foundation

// MARK: - DTOs

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

struct MatvaretabellenFoodGroupResponse: Decodable, Sendable {
    // The API returns an array directly
}

struct MatvaretabellenFoodGroup: Decodable, Sendable {
    let foodGroupId: String
    let name: String
    let parentId: String?
}

// MARK: - Service

actor MatvaretabellenService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func fetchFoods() async throws -> [MatvaretabellenFood] {
        guard let url = URL(string: Constants.API.matvaretabellenFoodsURL) else {
            throw MatvaretabellenError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MatvaretabellenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MatvaretabellenError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(MatvaretabellenResponse.self, from: data)
        return decoded.foods
    }

    func fetchFoodGroups() async throws -> [MatvaretabellenFoodGroup] {
        guard let url = URL(string: Constants.API.matvaretabellenFoodGroupsURL) else {
            throw MatvaretabellenError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MatvaretabellenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MatvaretabellenError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode([MatvaretabellenFoodGroup].self, from: data)
        return decoded
    }
}

// MARK: - Helpers

extension MatvaretabellenFood {
    var kcal: Double {
        calories?.quantity ?? 0
    }

    var protein: Double {
        nutrientQuantity(for: "Protein")
    }

    var carbs: Double {
        nutrientQuantity(for: "Karbo")
    }

    var fat: Double {
        nutrientQuantity(for: "Fett")
    }

    var fiber: Double? {
        let value = nutrientQuantity(for: "Fiber")
        return value > 0 ? value : nil
    }

    var primaryPortionLabel: String? {
        guard let portions, let first = portions.first else { return nil }
        return "\(first.portionName) (\(Int(first.quantity))g)"
    }

    private func nutrientQuantity(for id: String) -> Double {
        constituents?.first(where: { $0.nutrientId == id })?.quantity ?? 0
    }
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
