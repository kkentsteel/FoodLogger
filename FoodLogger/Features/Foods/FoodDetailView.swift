import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var food: FoodItem
    @State private var showDeleteAlert = false
    @State private var showLogSheet = false
    @State private var logQuantity: Double = 1.0
    @State private var showLogSuccess = false

    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]

    var body: some View {
        List {
            // Quick log section at top
            Section {
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log This Food", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                }
                .tint(.green)
            }

            Section {
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
                if let groupName = food.foodGroupName {
                    LabeledContent("Category", value: groupName)
                }
            } header: {
                Text("Details")
            }

            Section {
                LabeledContent("Calories", value: food.caloriesPerServing.formattedCalories)
                LabeledContent("Protein", value: food.proteinPerServing.formattedGrams)
                LabeledContent("Carbs", value: food.carbsPerServing.formattedGrams)
                LabeledContent("Fat", value: food.fatPerServing.formattedGrams)
                if let fiber = food.fiberPerServing {
                    LabeledContent("Fiber", value: fiber.formattedGrams)
                }
            } header: {
                Text("Macros (per serving)")
            }

            // Fat breakdown
            if hasFatDetails {
                Section {
                    optionalRow("Saturated", food.saturatedFatPerServing, unit: "g")
                    optionalRow("Monounsaturated", food.monounsaturatedFatPerServing, unit: "g")
                    optionalRow("Polyunsaturated", food.polyunsaturatedFatPerServing, unit: "g")
                    optionalRow("Trans Fat", food.transFatPerServing, unit: "g")
                    optionalRow("Omega-3", food.omega3PerServing, unit: "g")
                    optionalRow("Omega-6", food.omega6PerServing, unit: "g")
                    optionalRow("Cholesterol", food.cholesterolPerServing, unit: "mg")
                } header: {
                    Text("Fat Details")
                }
            }

            // Carb breakdown
            if hasCarbDetails {
                Section {
                    optionalRow("Sugar", food.sugarPerServing, unit: "g")
                    optionalRow("Added Sugar", food.addedSugarPerServing, unit: "g")
                    optionalRow("Starch", food.starchPerServing, unit: "g")
                } header: {
                    Text("Carb Details")
                }
            }

            // Other
            if hasSaltOrWater {
                Section {
                    optionalRow("Salt", food.saltPerServing, unit: "g")
                    optionalRow("Water", food.waterPerServing, unit: "g")
                } header: {
                    Text("Other")
                }
            }

            // Vitamins
            if hasVitamins {
                Section {
                    optionalRow("Vitamin A", food.vitaminAPerServing, unit: "µg RAE")
                    optionalRow("Vitamin D", food.vitaminDPerServing, unit: "µg")
                    optionalRow("Vitamin E", food.vitaminEPerServing, unit: "mg")
                    optionalRow("Vitamin C", food.vitaminCPerServing, unit: "mg")
                    optionalRow("Thiamin (B1)", food.vitaminB1PerServing, unit: "mg")
                    optionalRow("Riboflavin (B2)", food.vitaminB2PerServing, unit: "mg")
                    optionalRow("Niacin (B3)", food.niacinPerServing, unit: "mg")
                    optionalRow("Vitamin B6", food.vitaminB6PerServing, unit: "mg")
                    optionalRow("Folate (B9)", food.folatePerServing, unit: "µg")
                    optionalRow("Vitamin B12", food.vitaminB12PerServing, unit: "µg")
                } header: {
                    Text("Vitamins")
                }
            }

            // Minerals
            if hasMinerals {
                Section {
                    optionalRow("Calcium", food.calciumPerServing, unit: "mg")
                    optionalRow("Iron", food.ironPerServing, unit: "mg")
                    optionalRow("Magnesium", food.magnesiumPerServing, unit: "mg")
                    optionalRow("Phosphorus", food.phosphorusPerServing, unit: "mg")
                    optionalRow("Potassium", food.potassiumPerServing, unit: "mg")
                    optionalRow("Sodium", food.sodiumPerServing, unit: "mg")
                    optionalRow("Zinc", food.zincPerServing, unit: "mg")
                    optionalRow("Copper", food.copperPerServing, unit: "mg")
                    optionalRow("Selenium", food.seleniumPerServing, unit: "µg")
                    optionalRow("Iodine", food.iodinePerServing, unit: "µg")
                } header: {
                    Text("Minerals")
                }
            }

            Section {
                LabeledContent("Source", value: food.source.rawValue.capitalized)
                LabeledContent("Times Used", value: "\(food.usageCount)")
                if let lastUsed = food.lastUsedAt {
                    LabeledContent("Last Used", value: lastUsed.shortFormatted)
                }
                LabeledContent("Created", value: food.createdAt.shortFormatted)

                Toggle("Favorite", isOn: $food.isFavorite)
            } header: {
                Text("Info")
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
        .sheet(isPresented: $showLogSheet) {
            logFoodSheet
        }
        .overlay {
            if showLogSuccess {
                VStack {
                    Spacer()
                    Text("Logged!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.green, in: Capsule())
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer().frame(height: 20)
                }
                .animation(.easeInOut, value: showLogSuccess)
            }
        }
    }

    private var logFoodSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(food.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                Stepper(value: $logQuantity, in: 0.25...20, step: 0.25) {
                    Text("\(logQuantity.formattedOneDecimal) servings")
                        .font(.headline)
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("\(Int(food.caloriesPerServing * logQuantity)) kcal")
                        .font(.title2)
                        .fontWeight(.bold)
                    HStack(spacing: 16) {
                        Text("P: \((food.proteinPerServing * logQuantity).formattedGrams)")
                        Text("C: \((food.carbsPerServing * logQuantity).formattedGrams)")
                        Text("F: \((food.fatPerServing * logQuantity).formattedGrams)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        logFoodToToday()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func logFoodToToday() {
        guard let firstSlot = mealSlots.first else { return }
        let dbService = FoodDatabaseService(modelContext: modelContext)
        guard let dailyLog = try? dbService.getOrCreateDailyLog(for: Date()) else { return }

        let entry = LogEntry(quantity: logQuantity)
        entry.foodItem = food
        entry.mealSlot = firstSlot
        entry.dailyLog = dailyLog
        entry.captureSnapshot(from: food)

        food.usageCount += 1
        food.lastUsedAt = Date()
        food.updatedAt = Date()

        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()

        showLogSheet = false
        showLogSuccess = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showLogSuccess = false
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func optionalRow(_ label: String, _ value: Double?, unit: String) -> some View {
        if let value, value > 0 {
            LabeledContent(label, value: formatNutrient(value, unit: unit))
        }
    }

    private func formatNutrient(_ value: Double, unit: String) -> String {
        if value < 0.1 && value > 0 {
            return String(format: "%.3f %@", value, unit)
        } else if value < 10 {
            return String(format: "%.1f %@", value, unit)
        } else {
            return String(format: "%.0f %@", value, unit)
        }
    }

    private var hasFatDetails: Bool {
        [food.saturatedFatPerServing, food.monounsaturatedFatPerServing,
         food.polyunsaturatedFatPerServing, food.transFatPerServing,
         food.omega3PerServing, food.omega6PerServing, food.cholesterolPerServing]
            .contains { ($0 ?? 0) > 0 }
    }

    private var hasCarbDetails: Bool {
        [food.sugarPerServing, food.addedSugarPerServing, food.starchPerServing]
            .contains { ($0 ?? 0) > 0 }
    }

    private var hasSaltOrWater: Bool {
        [food.saltPerServing, food.waterPerServing].contains { ($0 ?? 0) > 0 }
    }

    private var hasVitamins: Bool {
        [food.vitaminAPerServing, food.vitaminDPerServing, food.vitaminEPerServing,
         food.vitaminCPerServing, food.vitaminB1PerServing, food.vitaminB2PerServing,
         food.vitaminB6PerServing, food.vitaminB12PerServing, food.niacinPerServing,
         food.folatePerServing]
            .contains { ($0 ?? 0) > 0 }
    }

    private var hasMinerals: Bool {
        [food.calciumPerServing, food.ironPerServing, food.magnesiumPerServing,
         food.potassiumPerServing, food.sodiumPerServing, food.zincPerServing,
         food.seleniumPerServing, food.phosphorusPerServing, food.copperPerServing,
         food.iodinePerServing]
            .contains { ($0 ?? 0) > 0 }
    }
}

struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var food: FoodItem

    private var isValid: Bool {
        !food.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        food.servingSize > 0 &&
        food.caloriesPerServing >= 0
    }

    var body: some View {
        Form {
            Section {
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
            } header: {
                Text("Details")
            } footer: {
                if food.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Name is required.")
                        .foregroundStyle(.red)
                }
            }

            Section {
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
            } header: {
                Text("Nutrition (per serving)")
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
                .disabled(!isValid)
            }
        }
    }
}
