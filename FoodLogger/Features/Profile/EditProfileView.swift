import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section("Personal Information") {
                Stepper("Age: \(profile.age)", value: $profile.age, in: 13...120)

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $profile.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("cm", value: $profile.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("cm")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Biological Sex") {
                Picker("Sex", selection: $profile.biologicalSex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Activity Level") {
                Picker("Activity Level", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                let tdee = TDEECalculator.calculateTDEE(
                    weightKg: profile.weightKg,
                    heightCm: profile.heightCm,
                    age: profile.age,
                    sex: profile.biologicalSex,
                    activityLevel: profile.activityLevel
                )
                LabeledContent("Estimated TDEE", value: "\(tdee) kcal/day")
                    .fontWeight(.medium)
            }
        }
        .navigationTitle("Edit Profile")
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
