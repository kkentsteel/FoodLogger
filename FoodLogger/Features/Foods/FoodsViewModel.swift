import SwiftData
import Foundation
import Observation
import Combine

@Observable
@MainActor
final class FoodsViewModel {
    var searchText = ""
    var filterMode: FilterMode = .all

    var searchResults: [FoodItem] = []
    var apiSearchResults: [CompactFood] = []
    var recentFoods: [FoodItem] = []
    var frequentFoods: [FoodItem] = []
    var isSearching = false
    var isSearchingAPI = false

    private var localSearchTask: Task<Void, Never>?
    private var apiSearchTask: Task<Void, Never>?
    private var cacheWarmTask: Task<Void, Never>?

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case recent = "Recent"
        case frequent = "Frequent"
    }

    /// Pre-fetch the search index + compact foods so API searches are fast
    func warmAPICache() {
        guard cacheWarmTask == nil else { return }
        cacheWarmTask = Task {
            _ = try? await MatvaretabellenService.shared.fetchSearchIndex()
            _ = try? await MatvaretabellenService.shared.fetchCompactFoods()
        }
    }

    func onSearchTextChanged(context: ModelContext) {
        localSearchTask?.cancel()
        apiSearchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            apiSearchResults = []
            isSearching = false
            isSearchingAPI = false
            return
        }

        isSearching = true
        isSearchingAPI = true
        let debounceMs = Constants.Defaults.searchDebounceMilliseconds

        // Local text search (matches name/brand)
        localSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(debounceMs))
            guard !Task.isCancelled else { return }

            let dbService = FoodDatabaseService(modelContext: context)
            do {
                let results = try dbService.searchFoods(query: query, limit: 50)
                guard !Task.isCancelled else { return }
                self.searchResults = results
            } catch {
                self.searchResults = []
            }
            self.isSearching = false
        }

        // Matvaretabellen search: fetch CompactFood results directly from API
        apiSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(debounceMs + 200))
            guard !Task.isCancelled else { return }

            // Wait for cache if still loading
            await cacheWarmTask?.value
            guard !Task.isCancelled else { return }

            do {
                let foods = try await MatvaretabellenService.shared.searchFoods(query: query, limit: 30)
                guard !Task.isCancelled else { return }

                // Filter out foods already in local search results (by matvaretabellenId)
                let localMatIds = Set(self.searchResults.compactMap(\.matvaretabellenId))
                self.apiSearchResults = foods.filter { !localMatIds.contains($0.id) }
            } catch {
                self.apiSearchResults = []
            }
            self.isSearchingAPI = false
        }
    }

    /// Import a CompactFood from the API into the local database as a FoodItem
    func importFood(_ compactFood: CompactFood, context: ModelContext) -> FoodItem {
        // Check if already imported
        let dbService = FoodDatabaseService(modelContext: context)
        if let existing = try? dbService.findByMatvaretabellenId(compactFood.id) {
            return existing
        }

        let foodItem = FoodItem(
            name: compactFood.foodName,
            servingSize: 100,
            servingUnit: .grams,
            caloriesPerServing: compactFood.kcal,
            proteinPerServing: compactFood.protein,
            carbsPerServing: compactFood.carbs,
            fatPerServing: compactFood.fat,
            fiberPerServing: compactFood.fiber,
            source: .matvaretabellen
        )

        // External IDs
        foodItem.matvaretabellenId = compactFood.id
        foodItem.foodGroupId = compactFood.foodGroupId
        foodItem.ediblePartPercent = compactFood.ediblePart

        // Fats
        foodItem.saturatedFatPerServing = compactFood.saturatedFat
        foodItem.monounsaturatedFatPerServing = compactFood.monounsaturatedFat
        foodItem.polyunsaturatedFatPerServing = compactFood.polyunsaturatedFat
        foodItem.transFatPerServing = compactFood.transFat
        foodItem.omega3PerServing = compactFood.omega3
        foodItem.omega6PerServing = compactFood.omega6
        foodItem.cholesterolPerServing = compactFood.cholesterol

        // Carbs detail
        foodItem.sugarPerServing = compactFood.sugar
        foodItem.addedSugarPerServing = compactFood.addedSugar
        foodItem.starchPerServing = compactFood.starch

        // Other
        foodItem.saltPerServing = compactFood.salt
        foodItem.waterPerServing = compactFood.water

        // Vitamins
        foodItem.vitaminAPerServing = compactFood.vitaminA
        foodItem.vitaminDPerServing = compactFood.vitaminD
        foodItem.vitaminEPerServing = compactFood.vitaminE
        foodItem.vitaminCPerServing = compactFood.vitaminC
        foodItem.vitaminB1PerServing = compactFood.vitaminB1
        foodItem.vitaminB2PerServing = compactFood.vitaminB2
        foodItem.vitaminB6PerServing = compactFood.vitaminB6
        foodItem.vitaminB12PerServing = compactFood.vitaminB12
        foodItem.niacinPerServing = compactFood.niacin
        foodItem.folatePerServing = compactFood.folate

        // Minerals
        foodItem.calciumPerServing = compactFood.calcium
        foodItem.ironPerServing = compactFood.iron
        foodItem.magnesiumPerServing = compactFood.magnesium
        foodItem.potassiumPerServing = compactFood.potassium
        foodItem.sodiumPerServing = compactFood.sodium
        foodItem.zincPerServing = compactFood.zinc
        foodItem.seleniumPerServing = compactFood.selenium
        foodItem.phosphorusPerServing = compactFood.phosphorus
        foodItem.copperPerServing = compactFood.copper
        foodItem.iodinePerServing = compactFood.iodine

        context.insert(foodItem)
        try? context.save()
        return foodItem
    }

    func loadSections(context: ModelContext) {
        let dbService = FoodDatabaseService(modelContext: context)
        recentFoods = (try? dbService.recentFoods(limit: 5)) ?? []
        frequentFoods = (try? dbService.frequentFoods(limit: 5)) ?? []
    }

    func deleteFood(_ food: FoodItem, context: ModelContext) {
        context.delete(food)
        try? context.save()
        loadSections(context: context)
    }
}
