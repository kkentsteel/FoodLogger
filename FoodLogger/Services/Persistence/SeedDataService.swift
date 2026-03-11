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

        // Fetch compact foods + food groups in parallel
        do {
            let count = try await seedFromCompactEndpoint()
            logger.info("Seeded \(count) foods from Matvaretabellen compact API")
            hasSeeded = true
            return
        } catch {
            logger.warning("Matvaretabellen compact API failed: \(error.localizedDescription). Falling back to local JSON.")
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

    // MARK: - Compact API Seed

    private func seedFromCompactEndpoint() async throws -> Int {
        let service = MatvaretabellenService.shared

        // Fetch both compact foods and food groups
        async let foodsTask = service.fetchCompactFoods()
        async let groupsTask = service.fetchFoodGroups()
        let (apiFoods, foodGroups) = try await (foodsTask, groupsTask)

        // Build food group name lookup
        let groupLookup = Dictionary(uniqueKeysWithValues: foodGroups.map { ($0.foodGroupId, $0.name) })

        var count = 0
        for apiFood in apiFoods {
            let kcal = apiFood.kcal
            guard kcal > 0 || apiFood.protein > 0 || apiFood.carbs > 0 || apiFood.fat > 0 else {
                continue
            }

            let foodItem = FoodItem(
                name: apiFood.foodName,
                servingSize: 100,
                servingUnit: .grams,
                caloriesPerServing: kcal,
                proteinPerServing: apiFood.protein,
                carbsPerServing: apiFood.carbs,
                fatPerServing: apiFood.fat,
                fiberPerServing: apiFood.fiber,
                source: .matvaretabellen
            )

            // External IDs
            foodItem.matvaretabellenId = apiFood.id
            foodItem.foodGroupId = apiFood.foodGroupId
            foodItem.foodGroupName = resolveTopLevelGroupName(
                foodGroupId: apiFood.foodGroupId,
                groupLookup: groupLookup,
                foodGroups: foodGroups
            )
            foodItem.ediblePartPercent = apiFood.ediblePart

            // Fats
            foodItem.saturatedFatPerServing = apiFood.saturatedFat
            foodItem.monounsaturatedFatPerServing = apiFood.monounsaturatedFat
            foodItem.polyunsaturatedFatPerServing = apiFood.polyunsaturatedFat
            foodItem.transFatPerServing = apiFood.transFat
            foodItem.omega3PerServing = apiFood.omega3
            foodItem.omega6PerServing = apiFood.omega6
            foodItem.cholesterolPerServing = apiFood.cholesterol

            // Carbs detail
            foodItem.sugarPerServing = apiFood.sugar
            foodItem.addedSugarPerServing = apiFood.addedSugar
            foodItem.starchPerServing = apiFood.starch

            // Other
            foodItem.saltPerServing = apiFood.salt
            foodItem.waterPerServing = apiFood.water

            // Vitamins
            foodItem.vitaminAPerServing = apiFood.vitaminA
            foodItem.vitaminDPerServing = apiFood.vitaminD
            foodItem.vitaminEPerServing = apiFood.vitaminE
            foodItem.vitaminCPerServing = apiFood.vitaminC
            foodItem.vitaminB1PerServing = apiFood.vitaminB1
            foodItem.vitaminB2PerServing = apiFood.vitaminB2
            foodItem.vitaminB6PerServing = apiFood.vitaminB6
            foodItem.vitaminB12PerServing = apiFood.vitaminB12
            foodItem.niacinPerServing = apiFood.niacin
            foodItem.folatePerServing = apiFood.folate

            // Minerals
            foodItem.calciumPerServing = apiFood.calcium
            foodItem.ironPerServing = apiFood.iron
            foodItem.magnesiumPerServing = apiFood.magnesium
            foodItem.potassiumPerServing = apiFood.potassium
            foodItem.sodiumPerServing = apiFood.sodium
            foodItem.zincPerServing = apiFood.zinc
            foodItem.seleniumPerServing = apiFood.selenium
            foodItem.phosphorusPerServing = apiFood.phosphorus
            foodItem.copperPerServing = apiFood.copper
            foodItem.iodinePerServing = apiFood.iodine

            modelContext.insert(foodItem)
            count += 1
        }

        try modelContext.save()
        return count
    }

    /// Walk up the food group hierarchy to find the top-level group name
    private func resolveTopLevelGroupName(
        foodGroupId: String,
        groupLookup: [String: String],
        foodGroups: [MatvaretabellenFoodGroup]
    ) -> String? {
        let byId = Dictionary(uniqueKeysWithValues: foodGroups.map { ($0.foodGroupId, $0) })
        var current = byId[foodGroupId]

        // Walk up to the top-level parent
        while let parent = current, let parentId = parent.parentId, let parentGroup = byId[parentId] {
            current = parentGroup
        }

        return current?.name ?? groupLookup[foodGroupId]
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
