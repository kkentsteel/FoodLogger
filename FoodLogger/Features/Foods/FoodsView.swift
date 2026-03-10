import SwiftUI
import SwiftData

struct FoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FoodsViewModel()

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]

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
        NavigationStack {
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
            .onAppear {
                viewModel.loadSections(context: modelContext)
            }
            .navigationTitle("Foods")
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food)
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
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.isSearching {
            HStack {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            }
        } else if viewModel.searchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            Section("Results (\(viewModel.searchResults.count))") {
                ForEach(viewModel.searchResults) { food in
                    NavigationLink(value: food) {
                        FoodItemRow(food: food)
                    }
                }
            }
        }
    }

    // MARK: - Browse Sections

    @ViewBuilder
    private var browseSections: some View {
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
        for index in offsets {
            let food = displayedFoods[index]
            viewModel.deleteFood(food, context: modelContext)
        }
    }
}
