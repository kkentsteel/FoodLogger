import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealSlot: MealSlot
    let date: Date

    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var showError = false
    @State private var errorMessage = ""

    @FocusState private var focusedField: Field?

    private enum Field {
        case calories, protein, carbs, fat
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Required", text: $caloriesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .calories)
                            .frame(width: 100)
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text("Enter at least the calorie amount.")
                }

                Section("Macros (Optional)") {
                    macroRow("Protein", text: $proteinText, field: .protein)
                    macroRow("Carbs", text: $carbsText, field: .carbs)
                    macroRow("Fat", text: $fatText, field: .fat)
                }

                if let preview = previewCalories {
                    Section("Preview") {
                        HStack {
                            Text("Total")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(preview) kcal")
                                .fontWeight(.semibold)
                        }
                        if let p = previewProtein, let c = previewCarbs, let f = previewFat,
                           p > 0 || c > 0 || f > 0 {
                            HStack(spacing: 16) {
                                Spacer()
                                Text("P: \(Int(p))g")
                                Text("C: \(Int(c))g")
                                Text("F: \(Int(f))g")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addEntry() }
                        .fontWeight(.semibold)
                        .disabled(previewCalories == nil)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                focusedField = .calories
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func macroRow(_ label: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                .frame(width: 100)
            Text("g")
                .foregroundStyle(.secondary)
        }
    }

    private var previewCalories: Int? {
        guard let cal = Double(caloriesText), cal > 0 else { return nil }
        return Int(cal)
    }

    private var previewProtein: Double? { Double(proteinText) }
    private var previewCarbs: Double? { Double(carbsText) }
    private var previewFat: Double? { Double(fatText) }

    private func addEntry() {
        guard let calories = Double(caloriesText), calories > 0 else {
            errorMessage = "Please enter a valid calorie amount."
            showError = true
            return
        }

        let protein = Double(proteinText) ?? 0
        let carbs = Double(carbsText) ?? 0
        let fat = Double(fatText) ?? 0

        let dbService = FoodDatabaseService(modelContext: modelContext)

        do {
            try dbService.logQuickAdd(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                mealSlot: mealSlot,
                date: date
            )
            HapticManager.success()
            dismiss()
        } catch {
            errorMessage = "Failed to save quick add entry."
            showError = true
            HapticManager.error()
        }
    }
}
