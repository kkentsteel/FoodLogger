import SwiftUI
import SwiftData

struct FoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FoodsViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var foodToDelete: FoodItem?
    @State private var showDeleteConfirmation = false

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    private var displayedFoods: [FoodItem] {
        switch viewModel.filterMode {
        case .all:
            return allFoods
        case .favorites:
            return allFoods.filter { $0.isFavorite }
        case .recent:
            return allFoods
                .filter { $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        case .frequent:
            return allFoods
                .filter { $0.usageCount > 0 }
                .sorted { $0.usageCount > $1.usageCount }
        }
    }

    private var isSearchActive: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if isSearchActive {
                    searchResultsSection
                } else {
                    browseSections
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search foods...")
            .onChange(of: viewModel.searchText) {
                viewModel.onSearchTextChanged(context: modelContext)
            }
            .refreshable {
                viewModel.loadSections(context: modelContext)
            }
            .onAppear {
                viewModel.loadSections(context: modelContext)
                viewModel.warmAPICache()
            }
            .navigationTitle("Foods")
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food)
            }
            .navigationDestination(for: SavedMeal.self) { meal in
                SavedMealDetailView(meal: meal)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        AddFoodView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filter", selection: $viewModel.filterMode) {
                            ForEach(FoodsViewModel.FilterMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .alert("Delete Food?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let food = foodToDelete {
                        viewModel.deleteFood(food, context: modelContext)
                        foodToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { foodToDelete = nil }
            } message: {
                if let food = foodToDelete {
                    Text(food.logEntries.count > 0
                         ? "'\(food.name)' has been logged \(food.logEntries.count) time(s). Deleting it will also remove those log entries."
                         : "Are you sure you want to delete '\(food.name)'?")
                }
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        // Local text search results
        if viewModel.isSearching {
            HStack {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            }
        } else if !viewModel.searchResults.isEmpty {
            Section("Your Foods (\(viewModel.searchResults.count))") {
                ForEach(viewModel.searchResults) { food in
                    NavigationLink(value: food) {
                        FoodItemRow(food: food)
                    }
                }
            }
        }

        // Matvaretabellen API results (CompactFood, not yet saved locally)
        if viewModel.isSearchingAPI {
            Section("Matvaretabellen") {
                HStack {
                    Spacer()
                    ProgressView("Searching Matvaretabellen...")
                        .font(.caption)
                    Spacer()
                }
            }
        } else if !viewModel.apiSearchResults.isEmpty {
            Section("Matvaretabellen (\(viewModel.apiSearchResults.count))") {
                ForEach(viewModel.apiSearchResults, id: \.id) { compactFood in
                    Button {
                        let imported = viewModel.importFood(compactFood, context: modelContext)
                        navigationPath.append(imported)
                    } label: {
                        CompactFoodRow(food: compactFood)
                    }
                    .tint(.primary)
                }
            }
        }

        // No results at all
        if !viewModel.isSearching && !viewModel.isSearchingAPI
            && viewModel.searchResults.isEmpty && viewModel.apiSearchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    // MARK: - Browse Sections

    @ViewBuilder
    private var browseSections: some View {
        if !savedMeals.isEmpty {
            Section("Saved Meals") {
                ForEach(savedMeals) { meal in
                    NavigationLink(value: meal) {
                        SavedMealRow(meal: meal)
                    }
                }
            }
        }

        NavigationLink {
            SavedMealsView()
        } label: {
            Label("Manage Saved Meals", systemImage: "tray.2.fill")
        }

        if !viewModel.recentFoods.isEmpty {
            Section("Recent") {
                ForEach(viewModel.recentFoods) { food in
                    NavigationLink(value: food) {
                        FoodItemRow(food: food)
                    }
                }
            }
        }

        if !viewModel.frequentFoods.isEmpty {
            Section("Frequent") {
                ForEach(viewModel.frequentFoods) { food in
                    NavigationLink(value: food) {
                        FoodItemRow(food: food)
                    }
                }
            }
        }

        Section("\(viewModel.filterMode.rawValue) (\(displayedFoods.count))") {
            ForEach(displayedFoods) { food in
                NavigationLink(value: food) {
                    FoodItemRow(food: food)
                }
            }
            .onDelete(perform: deleteFoods)

            if displayedFoods.isEmpty {
                ContentUnavailableView(
                    "No Foods",
                    systemImage: "fork.knife",
                    description: Text("Add foods to build your database.")
                )
            }
        }
    }

    private func deleteFoods(at offsets: IndexSet) {
        let foods = displayedFoods
        guard let first = offsets.first else { return }
        foodToDelete = foods[first]
        showDeleteConfirmation = true
    }
}

// MARK: - Delete Confirmation (added to body via extension)
extension FoodsView {
    @ViewBuilder
    var deleteConfirmationModifier: some View {
        EmptyView()
    }
}
