import SwiftUI
import SwiftData

struct AddFoodToMealSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealSlot: MealSlot?
    let date: Date

    // MARK: - State

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
    @State private var selectedCategory: FoodCategory = .all

    // Sub-sheet states
    @State private var showQuickAddSheet = false
    @State private var showVoiceLogSheet = false
    @State private var showBarcodeScanSheet = false
    @State private var showOCRScanSheet = false

    // MARK: - Queries

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    // MARK: - Enums

    enum FoodCategory: String, CaseIterable {
        case all = "All"
        case myMeals = "My Meals"
        case myFoods = "My Foods"
    }

    // MARK: - Computed

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
            .prefix(10)
            .map { $0 }
    }

    private var myFoods: [FoodItem] {
        let userSources: Set<FoodSource> = [.manual, .barcode, .ocr, .openFoodFacts]
        if searchText.isEmpty {
            return allFoods.filter { userSources.contains($0.source) }
        }
        let query = searchText.lowercased()
        return allFoods.filter {
            userSources.contains($0.source) &&
            ($0.name.lowercased().contains(query) || ($0.brand?.lowercased().contains(query) ?? false))
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Action buttons row
                ActionButtonsRow(
                    onBarcodeScan: { showBarcodeScanSheet = true },
                    onVoiceLog: { showVoiceLogSheet = true },
                    onMealScan: { showOCRScanSheet = true },
                    onQuickAdd: { showQuickAddSheet = true }
                )

                // Category tabs
                Picker("Category", selection: $selectedCategory) {
                    ForEach(FoodCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Meal slot picker (when opened from center + button)
                if mealSlot == nil && mealSlots.count > 1 {
                    Picker("Meal", selection: $selectedSlot) {
                        ForEach(mealSlots) { slot in
                            Text(slot.name).tag(Optional(slot))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Content
                contentForCategory
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
            .sheet(isPresented: $showQuickAddSheet, onDismiss: { dismiss() }) {
                if let slot = activeSlot {
                    QuickAddSheet(mealSlot: slot, date: date)
                }
            }
            .sheet(isPresented: $showVoiceLogSheet, onDismiss: { dismiss() }) {
                if let slot = activeSlot {
                    VoiceLogSheet(mealSlot: slot, date: date)
                }
            }
            .sheet(isPresented: $showBarcodeScanSheet) {
                BarcodeScannerView()
            }
            .sheet(isPresented: $showOCRScanSheet) {
                NutritionLabelScanView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Category Content

    @ViewBuilder
    private var contentForCategory: some View {
        switch selectedCategory {
        case .all:
            allFoodsListView
        case .myMeals:
            savedMealsListView
        case .myFoods:
            myFoodsListView
        }
    }

    // MARK: - All Foods Tab

    private var allFoodsListView: some View {
        List {
            if allFoods.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Foods Yet", systemImage: "fork.knife")
                } description: {
                    Text("Add your first food to start logging meals.")
                } actions: {
                    Button {
                        showAddFoodView = true
                    } label: {
                        Label("Create Food", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
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
    }

    // MARK: - My Meals Tab

    private var savedMealsListView: some View {
        List {
            if savedMeals.isEmpty {
                ContentUnavailableView(
                    "No Saved Meals",
                    systemImage: "tray",
                    description: Text("Save food combinations as meals in the Foods tab.")
                )
            } else {
                ForEach(savedMeals) { meal in
                    HStack {
                        SavedMealRow(meal: meal)

                        Button {
                            logSavedMeal(meal)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - My Foods Tab

    private var myFoodsListView: some View {
        List {
            if myFoods.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Personal Foods" : "No Results",
                    systemImage: "fork.knife",
                    description: Text(searchText.isEmpty
                        ? "Foods you create manually will appear here."
                        : "No matching foods found.")
                )
            } else {
                ForEach(myFoods) { food in
                    foodRow(food)
                }
            }
        }
    }

    // MARK: - Food Row

    private func foodRow(_ food: FoodItem) -> some View {
        HStack {
            Button {
                selectedFood = food
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(food.caloriesPerServing.formattedCalories)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(food.servingSize.formattedOneDecimal) \(food.servingUnit.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                quickLogFood(food)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quantity Sheet

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

    // MARK: - Actions

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

    private func quickLogFood(_ food: FoodItem) {
        guard let slot = activeSlot else {
            errorMessage = "No meal slot selected."
            showError = true
            HapticManager.error()
            return
        }

        let dbService = FoodDatabaseService(modelContext: modelContext)
        do {
            try dbService.logFood(food, quantity: 1.0, mealSlot: slot, date: date)
            HapticManager.success()
            dismiss()
        } catch {
            errorMessage = "Failed to log food."
            showError = true
            HapticManager.error()
        }
    }

    private func logSavedMeal(_ meal: SavedMeal) {
        guard let slot = activeSlot else {
            errorMessage = "No meal slot selected."
            showError = true
            HapticManager.error()
            return
        }

        let dbService = FoodDatabaseService(modelContext: modelContext)
        do {
            let count = try dbService.logSavedMeal(meal, mealSlot: slot, date: date)
            if count > 0 {
                HapticManager.success()
                dismiss()
            }
        } catch {
            errorMessage = "Failed to log meal."
            showError = true
            HapticManager.error()
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
            try? await Task.sleep(for: .milliseconds(Constants.Defaults.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }

            do {
                let foodIds = try await MatvaretabellenService.shared.searchFoodIds(query: query, limit: 20)
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
