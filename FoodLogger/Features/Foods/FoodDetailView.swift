import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var food: FoodItem
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: food.name)
                if let brand = food.brand, !brand.isEmpty {
                    LabeledContent("Brand", value: brand)
                }
                LabeledContent("Serving Size", value: "\(food.servingSize.formattedOneDecimal) \(food.servingUnit.rawValue)")
                if let label = food.servingLabel, !label.isEmpty {
                    LabeledContent("Serving Label", value: label)
                }
                if let barcode = food.barcode, !barcode.isEmpty {
                    LabeledContent("Barcode", value: barcode)
                }
            }

            Section("Nutrition (per serving)") {
                LabeledContent("Calories", value: food.caloriesPerServing.formattedCalories)
                LabeledContent("Protein", value: food.proteinPerServing.formattedGrams)
                LabeledContent("Carbs", value: food.carbsPerServing.formattedGrams)
                LabeledContent("Fat", value: food.fatPerServing.formattedGrams)
                if let fiber = food.fiberPerServing {
                    LabeledContent("Fiber", value: fiber.formattedGrams)
                }
            }

            Section("Info") {
                LabeledContent("Source", value: food.source.rawValue.capitalized)
                LabeledContent("Times Used", value: "\(food.usageCount)")
                if let lastUsed = food.lastUsedAt {
                    LabeledContent("Last Used", value: lastUsed.shortFormatted)
                }
                LabeledContent("Created", value: food.createdAt.shortFormatted)

                Toggle("Favorite", isOn: $food.isFavorite)
            }

            Section {
                Button("Delete Food", role: .destructive) {
                    showDeleteAlert = true
                }
            }
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Edit") {
                    EditFoodView(food: food)
                }
            }
        }
        .alert("Delete Food?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(food)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if food.logEntries.count > 0 {
                Text("This food has been logged \(food.logEntries.count) time(s). Deleting it will also remove those log entries.")
            } else {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var food: FoodItem

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $food.name)
                TextField("Brand (optional)", text: Binding(
                    get: { food.brand ?? "" },
                    set: { food.brand = $0.isEmpty ? nil : $0 }
                ))
                HStack {
                    TextField("Serving Size", value: $food.servingSize, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $food.servingUnit) {
                        ForEach(ServingUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
            }

            Section("Nutrition (per serving)") {
                TextField("Calories (kcal)", value: $food.caloriesPerServing, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Protein (g)", value: $food.proteinPerServing, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Carbs (g)", value: $food.carbsPerServing, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Fat (g)", value: $food.fatPerServing, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Fiber (g, optional)", value: $food.fiberPerServing, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Edit Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    food.updatedAt = Date()
                    dismiss()
                }
            }
        }
    }
}
