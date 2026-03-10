import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var age = 30
    @State private var weightKg = 70.0
    @State private var heightCm = 170.0
    @State private var biologicalSex: BiologicalSex = .male
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var macroMode: MacroMode = .caloriesOnly

    private var calculatedTDEE: Int {
        TDEECalculator.calculateTDEE(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: biologicalSex,
            activityLevel: activityLevel
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                ProgressView(value: Double(step + 1), total: 3)
                    .padding(.horizontal)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    targetsStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Step 0: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Welcome to FoodLogger")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track your nutrition with AI-powered insights.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Get Started") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 1: Profile
    private var profileStep: some View {
        Form {
            Section("Personal Information") {
                Stepper("Age: \(age)", value: $age, in: 13...120)

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("cm", value: $heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("cm")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Biological Sex") {
                Picker("Sex", selection: $biologicalSex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Activity Level") {
                Picker("Activity", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Button("Next") {
                    withAnimation { step = 2 }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Step 2: Targets
    private var targetsStep: some View {
        Form {
            Section("Tracking Mode") {
                Picker("Mode", selection: $macroMode) {
                    ForEach(MacroMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Your Estimated TDEE") {
                Text("\(calculatedTDEE) kcal/day")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This is your estimated daily calorie expenditure based on your profile. You can adjust your target later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Complete Setup") {
                    createProfile()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            age: age,
            weightKg: weightKg,
            heightCm: heightCm,
            biologicalSex: biologicalSex,
            activityLevel: activityLevel,
            macroMode: macroMode,
            targetCalories: calculatedTDEE
        )

        // Set macro targets if full macros mode
        if macroMode == .fullMacros {
            let macros = MacroCalculator.calculateDefaultMacros(fromCalories: calculatedTDEE)
            profile.targetProteinGrams = macros.proteinGrams
            profile.targetCarbsGrams = macros.carbsGrams
            profile.targetFatGrams = macros.fatGrams
        }

        modelContext.insert(profile)

        // Create default meal slots
        for (index, slot) in Constants.Defaults.defaultMealSlots.enumerated() {
            let mealSlot = MealSlot(name: slot.name, sortOrder: index, iconName: slot.icon)
            mealSlot.userProfile = profile
            modelContext.insert(mealSlot)
        }

        try? modelContext.save()
        dismiss()
    }
}
