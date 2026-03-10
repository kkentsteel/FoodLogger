import SwiftUI

struct TargetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section("Tracking Mode") {
                Picker("Mode", selection: $profile.macroMode) {
                    ForEach(MacroMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Calorie Target") {
                Stepper("\(profile.targetCalories) kcal", value: $profile.targetCalories, in: 800...6000, step: 50)

                Button("Set to TDEE") {
                    profile.targetCalories = TDEECalculator.calculateTDEE(
                        weightKg: profile.weightKg,
                        heightCm: profile.heightCm,
                        age: profile.age,
                        sex: profile.biologicalSex,
                        activityLevel: profile.activityLevel
                    )
                }
            }

            if profile.macroMode == .fullMacros {
                Section("Macro Targets") {
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("g", value: Binding(
                            get: { profile.targetProteinGrams ?? 0 },
                            set: { profile.targetProteinGrams = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("g", value: Binding(
                            get: { profile.targetCarbsGrams ?? 0 },
                            set: { profile.targetCarbsGrams = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("g", value: Binding(
                            get: { profile.targetFatGrams ?? 0 },
                            set: { profile.targetFatGrams = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    Button("Auto-calculate from calories") {
                        let macros = MacroCalculator.calculateDefaultMacros(fromCalories: profile.targetCalories)
                        profile.targetProteinGrams = macros.proteinGrams
                        profile.targetCarbsGrams = macros.carbsGrams
                        profile.targetFatGrams = macros.fatGrams
                    }
                }
            }
        }
        .navigationTitle("Nutrition Targets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    profile.updatedAt = Date()
                    dismiss()
                }
            }
        }
    }
}
