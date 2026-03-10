import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var servingSize: Double = 100
    @State private var servingUnit: ServingUnit = .grams
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double?
    @State private var barcode: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasAttemptedSave = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var nameError: String? {
        guard hasAttemptedSave || !name.isEmpty else { return nil }
        if trimmedName.isEmpty { return "Food name is required." }
        return nil
    }

    private var caloriesError: String? {
        guard hasAttemptedSave else { return nil }
        if calories < 0 { return "Calories cannot be negative." }
        return nil
    }

    private var servingSizeError: String? {
        guard hasAttemptedSave else { return nil }
        if servingSize <= 0 { return "Serving size must be greater than zero." }
        return nil
    }

    var isValid: Bool {
        !trimmedName.isEmpty && calories >= 0 && servingSize > 0
    }

    var body: some View {
        Form {
            Section {
                TextField("Food Name", text: $name)
                    .accessibilityLabel("Food name")
                if let error = nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(error)")
                }
                TextField("Brand (optional)", text: $brand)
                TextField("Barcode (optional)", text: $barcode)
                    .keyboardType(.numberPad)
            } header: {
                Text("Details")
            }

            Section {
                HStack {
                    TextField("Serving Size", value: $servingSize, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $servingUnit) {
                        ForEach(ServingUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
                if let error = servingSizeError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(error)")
                }
            } header: {
                Text("Serving")
            }

            Section {
                TextField("Calories (kcal)", value: $calories, format: .number)
                    .keyboardType(.decimalPad)
                if let error = caloriesError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(error)")
                }
                TextField("Protein (g)", value: $protein, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Carbs (g)", value: $carbs, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Fat (g)", value: $fat, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Fiber (g, optional)", value: $fiber, format: .number)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Nutrition (per serving)")
            }
        }
        .navigationTitle("Add Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    hasAttemptedSave = true
                    if isValid {
                        saveFood()
                    } else {
                        HapticManager.warning()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveFood() {
        let food = FoodItem(
            name: trimmedName,
            brand: brand.isEmpty ? nil : brand,
            barcode: barcode.isEmpty ? nil : barcode,
            servingSize: servingSize,
            servingUnit: servingUnit,
            caloriesPerServing: calories,
            proteinPerServing: protein,
            carbsPerServing: carbs,
            fatPerServing: fat,
            fiberPerServing: fiber,
            source: .manual
        )
        do {
            modelContext.insert(food)
            try modelContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            errorMessage = "Failed to save food: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }
}
