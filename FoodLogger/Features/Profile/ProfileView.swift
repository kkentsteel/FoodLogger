import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]
    @Query private var allFoods: [FoodItem]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            if let profile {
                List {
                    Section("Personal Stats") {
                        LabeledContent("Age", value: "\(profile.age)")
                        LabeledContent("Weight", value: "\(profile.weightKg.formattedOneDecimal) kg")
                        LabeledContent("Height", value: "\(profile.heightCm.formattedOneDecimal) cm")
                        LabeledContent("Sex", value: profile.biologicalSex.displayName)
                        LabeledContent("Activity", value: profile.activityLevel.displayName)

                        NavigationLink("Edit Profile") {
                            EditProfileView(profile: profile)
                        }
                    }

                    Section("Nutrition Targets") {
                        LabeledContent("Mode", value: profile.macroMode.displayName)
                        LabeledContent("Calories", value: "\(profile.targetCalories) kcal")

                        let tdee = TDEECalculator.calculateTDEE(
                            weightKg: profile.weightKg,
                            heightCm: profile.heightCm,
                            age: profile.age,
                            sex: profile.biologicalSex,
                            activityLevel: profile.activityLevel
                        )
                        LabeledContent("TDEE (calculated)", value: "\(tdee) kcal")

                        if profile.macroMode == .fullMacros {
                            LabeledContent("Protein", value: "\(Int(profile.targetProteinGrams ?? 0))g")
                            LabeledContent("Carbs", value: "\(Int(profile.targetCarbsGrams ?? 0))g")
                            LabeledContent("Fat", value: "\(Int(profile.targetFatGrams ?? 0))g")
                        }

                        NavigationLink("Edit Targets") {
                            TargetSettingsView(profile: profile)
                        }
                    }

                    Section("Meals") {
                        ForEach(mealSlots) { slot in
                            Label(slot.name, systemImage: slot.iconName)
                        }
                        NavigationLink("Manage Meals") {
                            MealConfigView(profile: profile)
                        }
                    }

                    Section("AI Assistant") {
                        NavigationLink("Manage API Key") {
                            APIKeySettingsView()
                        }
                    }

                    Section("Data") {
                        LabeledContent("Foods in Database", value: "\(allFoods.count)")
                    }
                }
                .navigationTitle("Profile")
            } else {
                ContentUnavailableView(
                    "No Profile",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Complete the setup to get started.")
                )
                .navigationTitle("Profile")
            }
        }
    }
}
