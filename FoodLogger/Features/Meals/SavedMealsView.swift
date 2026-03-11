import SwiftUI
import SwiftData

struct SavedMealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var showCreateSheet = false
    @State private var mealToDelete: SavedMeal?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            if savedMeals.isEmpty {
                ContentUnavailableView(
                    "No Saved Meals",
                    systemImage: "tray",
                    description: Text("Save combinations of foods as meals for quick logging.")
                )
            } else {
                ForEach(savedMeals) { meal in
                    NavigationLink {
                        SavedMealDetailView(meal: meal)
                    } label: {
                        SavedMealRow(meal: meal)
                    }
                }
                .onDelete(perform: confirmDelete)
            }
        }
        .navigationTitle("Saved Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                CreateSavedMealView()
            }
        }
        .alert("Delete Meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let meal = mealToDelete {
                    modelContext.delete(meal)
                    try? modelContext.save()
                    mealToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { mealToDelete = nil }
        } message: {
            if let meal = mealToDelete {
                Text("Are you sure you want to delete '\(meal.name)'?")
            }
        }
    }

    private func confirmDelete(at offsets: IndexSet) {
        guard let first = offsets.first else { return }
        mealToDelete = savedMeals[first]
        showDeleteConfirmation = true
    }
}
