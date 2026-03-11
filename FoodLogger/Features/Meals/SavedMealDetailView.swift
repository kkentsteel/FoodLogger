import SwiftUI
import SwiftData

struct SavedMealDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let meal: SavedMeal

    @State private var showLogSheet = false
    @State private var showEditSheet = false
    @State private var showError = false
    @State private var errorMessage = ""

    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]

    var body: some View {
        List {
            Section("Nutrition Summary") {
                HStack {
                    Text("Total Calories")
                    Spacer()
                    Text("\(Int(meal.totalCalories)) kcal")
                        .fontWeight(.semibold)
                }
                HStack(spacing: 16) {
                    macroLabel("Protein", value: meal.totalProtein)
                    macroLabel("Carbs", value: meal.totalCarbs)
                    macroLabel("Fat", value: meal.totalFat)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Foods (\(meal.items.count))") {
                ForEach(meal.items) { item in
                    if let food = item.foodItem {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name)
                                    .font(.subheadline)
                                if let brand = food.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.quantity.formattedOneDecimal) serving\(item.quantity == 1.0 ? "" : "s")")
                                    .font(.caption)
                                Text("\(Int(food.caloriesPerServing * item.quantity)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if meal.usageCount > 0 {
                Section("Stats") {
                    HStack {
                        Text("Times logged")
                        Spacer()
                        Text("\(meal.usageCount)")
                            .foregroundStyle(.secondary)
                    }
                    if let lastUsed = meal.lastUsedAt {
                        HStack {
                            Text("Last used")
                            Spacer()
                            Text(lastUsed.shortFormatted)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log This Meal", systemImage: "plus.circle.fill")
                }
                .tint(.accentColor)

                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Meal", systemImage: "pencil")
                }
            }
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Log to which meal?", isPresented: $showLogSheet, titleVisibility: .visible) {
            ForEach(mealSlots) { slot in
                Button(slot.name) {
                    logMeal(to: slot)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                CreateSavedMealView(existingMeal: meal)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func macroLabel(_ label: String, value: Double) -> some View {
        VStack {
            Text("\(Int(value))g")
                .fontWeight(.medium)
            Text(label)
        }
        .frame(maxWidth: .infinity)
    }

    private func logMeal(to slot: MealSlot) {
        let dbService = FoodDatabaseService(modelContext: modelContext)
        do {
            let count = try dbService.logSavedMeal(meal, mealSlot: slot, date: Date())
            if count > 0 {
                HapticManager.success()
            }
        } catch {
            errorMessage = "Failed to log meal."
            showError = true
            HapticManager.error()
        }
    }
}
