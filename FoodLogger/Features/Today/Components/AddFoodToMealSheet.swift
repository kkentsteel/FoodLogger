import SwiftUI
import SwiftData

struct AddFoodToMealSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealSlot: MealSlot?
    let date: Date

    @State private var searchText = ""
    @State private var quantity: Double = 1.0
    @State private var selectedFood: FoodItem?
    @State private var showAddFoodView = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var apiResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedSlot: MealSlot?

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]

    private var activeSlot: MealSlot? {
        selectedSlot ?? mealSlot ?? mealSlots.first
    }

    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty {
            return Array(allFoods.prefix(20))
        }
        let query = searchText.lowercased()
        return allFoods.filter {
            $0.name.lowercased().contains(query) ||
            ($0.brand?.lowercased().contains(query) ?? false)
        }
    }

    private var recentFoods: [FoodItem] {
        allFoods
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allFoods.isEmpty && searchText.isEmpty {
                    emptyDatabaseView
                } else {
                    foodListView
                }
            }
            .searchable(text: $searchText, prompt: "Search foods...")
            .onChange(of: searchText) {
                onSearchTextChanged()
            }
            .onAppear {
                if selectedSlot == nil {
                    selectedSlot = mealSlot ?? mealSlots.first
                }
            }
            .task {
                _ = try? await MatvaretabellenService.shared.fetchSearchIndex()
            }
            .navigationTitle(mealSlot != nil ? "Add to \(mealSlot!.name)" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        searchTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Food") { showAddFoodView = true }
                }
            }
            .sheet(isPresented: $showAddFoodView) {
                NavigationStack {
                    AddFoodView()
                }
            }
            .sheet(item: $selectedFood) { food in
                quantitySheet(for: food)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - API Search

    private func onSearchTextChanged() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, query.count >= 2 else {
            apiResults = []
            isSearchingAPI = false
            return
        }

        isSearchingAPI = true

        searchTask = Task {
            // Only debounce the API call, local search is instant via filteredFoods
            try? await Task.sleep(for: .milliseconds(Constants.Defaults.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }

            do {
                // Use search index to find food IDs, then look up in local DB
                let foodIds = try await MatvaretabellenService.shared.searchFoodIds(query: query, limit: 20)
                guard !Task.isCancelled else { return }

                let dbService = FoodDatabaseService(modelContext: modelContext)
                let foods = try dbService.findByMatvaretabellenIds(foodIds)
                guard !Task.isCancelled else { return }

                // Filter out foods already shown in the text search results
                let localIds = Set(filteredFoods.map(\.id))
                self.apiResults = foods.filter { !localIds.contains($0.id) }
            } catch {
                self.apiResults = []
            }
            self.isSearchingAPI = false
        }
    }

    // MARK: - Empty Database View

    private var emptyDatabaseView: some View {
        ContentUnavailableView {
            Label("No Foods Yet", systemImage: "fork.knife")
        } description: {
            Text("Add your first food to start logging meals. You can also scan barcodes or nutrition labels from the Scan tab.")
        } actions: {
            Button {
                showAddFoodView = true
            } label: {
                Label("Create Food", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Food List

    private var foodListView: some View {
        List {
            if mealSlot == nil && mealSlots.count > 1 {
                Section {
                    Picker("Meal", selection: $selectedSlot) {
                        ForEach(mealSlots) { slot in
                            Text(slot.name).tag(Optional(slot))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if searchText.isEmpty && !recentFoods.isEmpty {
                Section("Recent") {
                    ForEach(recentFoods) { food in
                        foodRow(food)
                    }
                }
            }

            Section(searchText.isEmpty ? "All Foods" : "Results") {
                ForEach(filteredFoods) { food in
                    foodRow(food)
                }
            }

            if !searchText.isEmpty {
                if isSearchingAPI {
                    Section("Matvaretabellen") {
                        HStack {
                            Spacer()
                            ProgressView("Searching Matvaretabellen...")
                                .font(.caption)
                            Spacer()
                        }
                    }
                } else if !apiResults.isEmpty {
                    Section("Matvaretabellen (\(apiResults.count))") {
                        ForEach(apiResults) { food in
                            foodRow(food)
                        }
                    }
                }

                if filteredFoods.isEmpty && apiResults.isEmpty && !isSearchingAPI {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button {
            selectedFood = food
        } label: {
            HStack {
                VStack(alignment: .leading) {
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

    private func quantitySheet(for food: FoodItem) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(food.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                VStack(spacing: 8) {
                    Text("Serving: \(food.servingSize.formattedOneDecimal) \(food.servingUnit.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Stepper(value: $quantity, in: 0.25...20, step: 0.25) {
                        Text("\(quantity.formattedOneDecimal) servings")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 4) {
                    Text("\(Int(food.caloriesPerServing * quantity)) kcal")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Text("P: \((food.proteinPerServing * quantity).formattedGrams)")
                        Text("C: \((food.carbsPerServing * quantity).formattedGrams)")
                        Text("F: \((food.fatPerServing * quantity).formattedGrams)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Set Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedFood = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        logFood(food)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func logFood(_ food: FoodItem) {
        guard let slot = activeSlot else {
            errorMessage = "No meal slot selected. Please select a meal."
            showError = true
            HapticManager.error()
            return
        }

        let dbService = FoodDatabaseService(modelContext: modelContext)

        do {
            try dbService.logFood(food, quantity: quantity, mealSlot: slot, date: date)
            HapticManager.success()
        } catch {
            errorMessage = "Failed to save food entry. Please try again."
            showError = true
            HapticManager.error()
            return
        }

        selectedFood = nil
        dismiss()
    }
}
