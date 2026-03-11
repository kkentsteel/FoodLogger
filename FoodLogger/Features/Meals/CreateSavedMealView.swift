import SwiftUI
import SwiftData

struct CreateSavedMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingMeal: SavedMeal?

    @State private var name = ""
    @State private var selectedIcon = "tray.fill"
    @State private var items: [(food: FoodItem, quantity: Double)] = []
    @State private var showFoodPicker = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let iconOptions = [
        "tray.fill", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "fork.knife", "carrot.fill", "fish.fill",
        "birthday.cake.fill", "mug.fill"
    ]

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g., My Breakfast", text: $name)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.food.name)
                                .font(.subheadline)
                            Text("\(Int(item.food.caloriesPerServing * item.quantity)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Stepper(
                            "\(item.quantity.formattedOneDecimal)",
                            value: Binding(
                                get: { items[index].quantity },
                                set: { items[index].quantity = $0 }
                            ),
                            in: 0.25...20,
                            step: 0.25
                        )
                        .frame(width: 160)
                    }
                }
                .onDelete(perform: removeItems)

                Button {
                    showFoodPicker = true
                } label: {
                    Label("Add Food", systemImage: "plus.circle")
                }
            } header: {
                Text("Foods (\(items.count))")
            } footer: {
                if !items.isEmpty {
                    Text("Total: \(Int(totalCalories)) kcal")
                }
            }
        }
        .navigationTitle(existingMeal == nil ? "New Meal" : "Edit Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
            }
        }
        .sheet(isPresented: $showFoodPicker) {
            MealFoodPickerSheet { food in
                items.append((food: food, quantity: 1.0))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if let meal = existingMeal {
                name = meal.name
                selectedIcon = meal.iconName
                items = meal.items.compactMap { item in
                    guard let food = item.foodItem else { return nil }
                    return (food: food, quantity: item.quantity)
                }
            }
        }
    }

    private var totalCalories: Double {
        items.reduce(0) { $0 + $1.food.caloriesPerServing * $1.quantity }
    }

    private func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !items.isEmpty else { return }

        if let meal = existingMeal {
            // Update existing
            meal.name = trimmedName
            meal.iconName = selectedIcon
            meal.updatedAt = Date()

            // Remove old items
            for item in meal.items {
                modelContext.delete(item)
            }
            meal.items = []

            // Add new items
            for item in items {
                let mealItem = SavedMealItem(quantity: item.quantity)
                mealItem.foodItem = item.food
                mealItem.savedMeal = meal
                modelContext.insert(mealItem)
            }
        } else {
            // Create new
            let meal = SavedMeal(name: trimmedName, iconName: selectedIcon)
            modelContext.insert(meal)

            for item in items {
                let mealItem = SavedMealItem(quantity: item.quantity)
                mealItem.foodItem = item.food
                mealItem.savedMeal = meal
                modelContext.insert(mealItem)
            }
        }

        do {
            try modelContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            errorMessage = "Failed to save meal."
            showError = true
            HapticManager.error()
        }
    }
}
