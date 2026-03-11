import Foundation

// MARK: - DTOs

struct OFFResponse: Decodable, Sendable {
    let status: Int            // 1 = found, 0 = not found
    let product: OFFProduct?
}

struct OFFProduct: Decodable, Sendable {
    let productName: String?
    let brands: String?
    let code: String?
    let servingSize: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case code
        case servingSize = "serving_size"
        case nutriments
    }
}

struct OFFNutriments: Decodable, Sendable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
    }
}

// MARK: - Service

actor OpenFoodFactsService {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    /// Look up a food product by barcode. Returns nil if not found.
    func lookupBarcode(_ barcode: String) async throws -> OFFProduct? {
        // Validate barcode contains only digits and is a plausible length
        let trimmed = barcode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.allSatisfy(\.isNumber),
              (7...14).contains(trimmed.count) else {
            throw NetworkError.invalidURL
        }

        let urlString = "\(Constants.API.offBaseURL)/\(trimmed).json"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(Constants.API.offUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)

        guard decoded.status == 1, let product = decoded.product else {
            return nil
        }

        return product
    }
}

// MARK: - Conversion Helper

extension OFFProduct {
    /// Convert OFF product to a data tuple for creating a FoodItem.
    var asFoodData: (name: String, brand: String?, barcode: String?, calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double?) {
        let name = productName ?? "Unknown Product"
        let brand = brands
        let kcal = nutriments?.energyKcal100g ?? 0
        let protein = nutriments?.proteins100g ?? 0
        let carbs = nutriments?.carbohydrates100g ?? 0
        let fat = nutriments?.fat100g ?? 0
        let fiber = nutriments?.fiber100g

        return (name, brand, code, kcal, protein, carbs, fat, fiber)
    }
}
