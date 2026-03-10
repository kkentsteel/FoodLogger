import SwiftUI

/// Shows OCR-parsed nutrition data for user confirmation and editing.
struct OCRResultView: View {
    let nutrition: NutritionLabelParser.ParsedNutrition
    let capturedImage: UIImage?
    let onSave: (String, String?) -> Void
    var onSaveAndLog: ((String, String?) -> Void)?
    let onRetake: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedBrand: String? {
        brand.isEmpty ? nil : brand
    }

    var body: some View {
        NavigationStack {
            Form {
                // Confidence indicator
                Section {
                    confidenceView
                }

                // Captured image thumbnail
                if let image = capturedImage {
                    Section("Captured Image") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Captured nutrition label photo")
                    }
                }

                // Food details
                Section("Food Details") {
                    TextField("Food Name (required)", text: $name)
                        .accessibilityLabel("Food name, required")
                    TextField("Brand (optional)", text: $brand)
                        .accessibilityLabel("Brand name, optional")
                }

                // Parsed nutrition (editable)
                Section {
                    nutritionRow("Calories", value: $calories, unit: "kcal")
                    nutritionRow("Protein", value: $protein, unit: "g")
                    nutritionRow("Carbs", value: $carbs, unit: "g")
                    nutritionRow("Fat", value: $fat, unit: "g")
                    nutritionRow("Fiber", value: $fiber, unit: "g")
                } header: {
                    Text("Nutrition (per 100g)")
                } footer: {
                    if nutrition.servingSize != nil {
                        Text("Detected serving: \(nutrition.servingSize!)")
                    }
                }

                // Save & Log section
                if let saveAndLog = onSaveAndLog {
                    Section {
                        Button {
                            saveAndLog(trimmedName, trimmedBrand)
                            dismiss()
                        } label: {
                            Label("Save & Log to Today", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(!isValid)
                        .accessibilityHint("Saves the food and adds it to today's first meal")
                    } footer: {
                        Text("Saves the food and logs 1 serving to your first meal slot today.")
                    }
                }
            }
            .navigationTitle("Scanned Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retake") {
                        onRetake()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedName, trimmedBrand)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                calories = nutrition.calories ?? 0
                protein = nutrition.protein ?? 0
                carbs = nutrition.carbs ?? 0
                fat = nutrition.fat ?? 0
                fiber = nutrition.fiber ?? 0
            }
        }
    }

    // MARK: - Confidence

    private var confidenceView: some View {
        HStack {
            Image(systemName: confidenceIcon)
                .foregroundStyle(confidenceColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(confidenceLabel)
                    .font(.headline)
                Text("Confidence: \(Int(nutrition.confidence * 100))% — \(nutrition.filledFieldCount)/5 fields detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(confidenceLabel), \(Int(nutrition.confidence * 100)) percent confidence, \(nutrition.filledFieldCount) of 5 fields detected")
    }

    private var confidenceIcon: String {
        if nutrition.confidence >= 0.7 { return "checkmark.circle.fill" }
        if nutrition.confidence >= 0.3 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private var confidenceColor: Color {
        if nutrition.confidence >= 0.7 { return .green }
        if nutrition.confidence >= 0.3 { return .orange }
        return .red
    }

    private var confidenceLabel: String {
        if nutrition.confidence >= 0.7 { return "Good Recognition" }
        if nutrition.confidence >= 0.3 { return "Partial Recognition" }
        return "Poor Recognition — Please Verify"
    }

    private func nutritionRow(_ label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(unit, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .accessibilityLabel("\(label) value")
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .leading)
        }
    }
}
