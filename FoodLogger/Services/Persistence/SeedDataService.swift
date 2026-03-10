import Foundation
import SwiftData
import OSLog

@MainActor
final class SeedDataService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.foodlogger.app", category: "SeedData")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private static let seedCompletedKey = "com.foodlogger.seedCompleted"

    /// Whether the initial seed has already been performed (persists across launches).
    private var hasSeeded: Bool {
        get { UserDefaults.standard.bool(forKey: Self.seedCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.seedCompletedKey) }
    }

    /// Seeds the database on first launch only. Once seeded, never re-seeds even if foods are deleted.
    func seedIfNeeded() async {
        guard !hasSeeded else {
            logger.info("Seed already completed previously, skipping")
            return
        }

        var descriptor = FetchDescriptor<FoodItem>()
        descriptor.fetchLimit = 1
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else {
            logger.info("Database already has foods, marking seed as complete")
            hasSeeded = true
            return
        }

        logger.info("First launch with no foods, starting seed...")

        // Try API first
        do {
            let count = try await seedFromMatvaretabellen()
            logger.info("Seeded \(count) foods from Matvaretabellen API")
            hasSeeded = true
            return
        } catch {
            logger.warning("Matvaretabellen API failed: \(error.localizedDescription). Falling back to local JSON.")
        }

        // Fallback to local JSON
        do {
            let count = try seedFromLocalJSON()
            logger.info("Seeded \(count) foods from local JSON")
            hasSeeded = true
        } catch {
            logger.error("Local JSON seed also failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Matvaretabellen API Seed

    private func seedFromMatvaretabellen() async throws -> Int {
        let service = MatvaretabellenService()
        let apiFoods = try await service.fetchFoods()

        var count = 0
        for apiFood in apiFoods {
            let kcal = apiFood.kcal
            // Skip foods with no calorie data
            guard kcal > 0 || apiFood.protein > 0 || apiFood.carbs > 0 || apiFood.fat > 0 else {
                continue
            }

            let foodItem = FoodItem(
                name: apiFood.foodName,
                servingSize: 100,
                servingUnit: .grams,
                servingLabel: apiFood.primaryPortionLabel,
                caloriesPerServing: kcal,
                proteinPerServing: apiFood.protein,
                carbsPerServing: apiFood.carbs,
                fatPerServing: apiFood.fat,
                fiberPerServing: apiFood.fiber,
                source: .matvaretabellen
            )
            foodItem.matvaretabellenId = apiFood.foodId
            foodItem.foodGroupId = apiFood.foodGroupId

            modelContext.insert(foodItem)
            count += 1
        }

        try modelContext.save()
        return count
    }

    // MARK: - Local JSON Fallback

    private func seedFromLocalJSON() throws -> Int {
        guard let url = Bundle.main.url(forResource: "norwegian_foods_seed", withExtension: "json") else {
            throw SeedError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let categories = try JSONDecoder().decode([SeedCategory].self, from: data)

        var count = 0
        for category in categories {
            for item in category.items {
                let foodItem = FoodItem(
                    name: item.name,
                    servingSize: item.servingSize,
                    servingUnit: ServingUnit(rawValue: item.servingUnit) ?? .grams,
                    servingLabel: item.servingLabel,
                    caloriesPerServing: item.calories,
                    proteinPerServing: item.protein,
                    carbsPerServing: item.carbs,
                    fatPerServing: item.fat,
                    fiberPerServing: item.fiber,
                    source: .seed
                )

                modelContext.insert(foodItem)
                count += 1
            }
        }

        try modelContext.save()
        return count
    }
}

// MARK: - Local JSON DTOs

private struct SeedCategory: Decodable {
    let category: String
    let items: [SeedFoodItem]
}

private struct SeedFoodItem: Decodable {
    let name: String
    let servingSize: Double
    let servingUnit: String
    let servingLabel: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
}

// MARK: - Errors

enum SeedError: LocalizedError {
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "norwegian_foods_seed.json not found in bundle"
        }
    }
}
