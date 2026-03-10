import SwiftUI

struct ScanResultView: View {
    @Binding var result: BarcodeScannerViewModel.ScannedFoodResult
    let isNewFood: Bool
    var networkError: Bool = false
    let onSave: () -> Void
    var onSaveAndLog: (() -> Void)?
    let onDiscard: () -> Void
    var onRetryLookup: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var isValid: Bool {
        !result.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status header
                Section {
                    statusHeader
                }

                // Retry banner for network errors
                if networkError && isNewFood {
                    Section {
                        retryBanner
                    }
                }

                // Editable details
                Section("Details") {
                    TextField("Food Name", text: $result.name)
                        .accessibilityLabel("Food name")
                    TextField("Brand (optional)", text: Binding(
                        get: { result.brand ?? "" },
                        set: { result.brand = $0.isEmpty ? nil : $0 }
                    ))
                    .accessibilityLabel("Brand name, optional")
                }

                // Nutrition (per 100g)
                Section("Nutrition (per 100g)") {
                    nutritionRow("Calories", value: $result.calories, unit: "kcal")
                    nutritionRow("Protein", value: $result.protein, unit: "g")
                    nutritionRow("Carbs", value: $result.carbs, unit: "g")
                    nutritionRow("Fat", value: $result.fat, unit: "g")
                    nutritionRow("Fiber", value: Binding(
                        get: { result.fiber ?? 0 },
                        set: { result.fiber = $0 == 0 ? nil : $0 }
                    ), unit: "g")
                }

                // Source info
                if !isNewFood {
                    Section("Source") {
                        LabeledContent("From", value: result.source.rawValue.capitalized)
                        if result.existingFoodItem != nil {
                            Label("Already in your database", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Save & Log section (only for new foods or OFF results)
                if result.existingFoodItem == nil, let saveAndLog = onSaveAndLog {
                    Section {
                        Button {
                            saveAndLog()
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
            .navigationTitle(isNewFood ? "Add Scanned Food" : "Scanned Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(result.existingFoodItem != nil ? "Done" : "Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Components

    private var statusHeader: some View {
        HStack {
            Image(systemName: isNewFood ? "questionmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(isNewFood ? .orange : .green)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(isNewFood ? "Not Found in Database" : "Food Found")
                    .font(.headline)
                Text("Barcode: \(result.barcode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isNewFood ? "Food not found in database" : "Food found in database")
        .accessibilityValue("Barcode \(result.barcode)")
    }

    private var retryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Network Lookup Failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("The product may exist online. Tap retry to try again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onRetry = onRetryLookup {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Network lookup failed. Tap retry to search online again.")
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
        }
    }
}
