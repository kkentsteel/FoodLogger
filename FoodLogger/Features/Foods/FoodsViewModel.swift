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
    var recentFoods: [FoodItem] = []
    var frequentFoods: [FoodItem] = []
    var isSearching = false

    private var searchTask: Task<Void, Never>?

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case recent = "Recent"
        case frequent = "Frequent"
    }

    func onSearchTextChanged(context: ModelContext) {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        let debounceMs = Constants.Defaults.searchDebounceMilliseconds

        searchTask = Task {
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
    }

    func loadSections(context: ModelContext) {
        let dbService = FoodDatabaseService(modelContext: context)
        recentFoods = (try? dbService.recentFoods(limit: 5)) ?? []
        frequentFoods = (try? dbService.frequentFoods(limit: 5)) ?? []
    }

    func deleteFood(_ food: FoodItem, context: ModelContext) {
        context.delete(food)
        try? context.save()
        // Refresh sections
        loadSections(context: context)
    }
}
