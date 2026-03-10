import Testing
@testable import FoodLogger

struct UserProfileTests {
    @Test func defaultValues() {
        let profile = UserProfile()
        #expect(profile.age == 30)
        #expect(profile.weightKg == 70.0)
        #expect(profile.heightCm == 170.0)
        #expect(profile.biologicalSex == .male)
        #expect(profile.activityLevel == .moderatelyActive)
        #expect(profile.macroMode == .caloriesOnly)
        #expect(profile.targetCalories == 2000)
        #expect(profile.targetProteinGrams == nil)
        #expect(profile.useMetricUnits == true)
        #expect(profile.mealSlots.isEmpty)
    }

    @Test func customValues() {
        let profile = UserProfile(
            age: 25,
            weightKg: 65,
            heightCm: 165,
            biologicalSex: .female,
            activityLevel: .veryActive,
            macroMode: .fullMacros,
            targetCalories: 2200,
            targetProteinGrams: 150,
            targetCarbsGrams: 220,
            targetFatGrams: 73
        )
        #expect(profile.age == 25)
        #expect(profile.biologicalSex == .female)
        #expect(profile.macroMode == .fullMacros)
        #expect(profile.targetProteinGrams == 150)
    }
}
