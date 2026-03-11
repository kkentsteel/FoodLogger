import SwiftUI
import SwiftData

struct MealFoodPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onSelect: (FoodItem) -> Void

    @State private var searchText = ""
    @State private var apiResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>?

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]

    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty {
            return allFoods
                .filter { $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
                .prefix(20)
                .map { $0 }
        }
        let query = searchText.lowercased()
        return allFoods.filter {
            $0.name.lowercased().contains(query) ||
            ($0.brand?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section("Recent Foods") {
                        ForEach(filteredFoods) { food in
                            foodButton(food)
                        }
                    }
                } else {
                    Section("Results") {
                        ForEach(filteredFoods) { food in
                            foodButton(food)
                        }
                    }

                    if isSearchingAPI {
                        Section("Matvaretabellen") {
                            HStack {
                                Spacer()
                                ProgressView("Searching...")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    } else if !apiResults.isEmpty {
                        Section("Matvaretabellen (\(apiResults.count))") {
                            ForEach(apiResults) { food in
                                foodButton(food)
                            }
                        }
                    }
                }

                if filteredFoods.isEmpty && apiResults.isEmpty && !searchText.isEmpty && !isSearchingAPI {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods...")
            .onChange(of: searchText) {
                onSearchChanged()
            }
            .navigationTitle("Add Food to Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        searchTask?.cancel()
                        dismiss()
                    }
                }
            }
        }
    }

    private func foodButton(_ food: FoodItem) -> some View {
        Button {
            onSelect(food)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(food.caloriesPerServing.formattedCalories)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func onSearchChanged() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, query.count >= 2 else {
            apiResults = []
            isSearchingAPI = false
            return
        }

        isSearchingAPI = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(Constants.Defaults.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }

            do {
                let foodIds = try await MatvaretabellenService.shared.searchFoodIds(query: query, limit: 15)
                guard !Task.isCancelled else { return }

                let dbService = FoodDatabaseService(modelContext: modelContext)
                let foods = try dbService.findByMatvaretabellenIds(foodIds)
                guard !Task.isCancelled else { return }

                let localIds = Set(filteredFoods.map(\.id))
                self.apiResults = foods.filter { !localIds.contains($0.id) }
            } catch {
                self.apiResults = []
            }
            self.isSearchingAPI = false
        }
    }
}
