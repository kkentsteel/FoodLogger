import Testing
@testable import FoodLogger

struct TDEECalculatorTests {
    @Test func calculateBMR_male() {
        // Male, 80kg, 180cm, age 30: BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let bmr = TDEECalculator.calculateBMR(weightKg: 80, heightCm: 180, age: 30, sex: .male)
        #expect(bmr == 1780.0)
    }

    @Test func calculateBMR_female() {
        // Female, 65kg, 165cm, age 25: BMR = 10*65 + 6.25*165 - 5*25 - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
        let bmr = TDEECalculator.calculateBMR(weightKg: 65, heightCm: 165, age: 25, sex: .female)
        #expect(bmr == 1395.25)
    }

    @Test func calculateTDEE_moderatelyActive() {
        // Male, 80kg, 180cm, age 30, moderately active: BMR 1780 * 1.55 = 2759
        let tdee = TDEECalculator.calculateTDEE(
            weightKg: 80, heightCm: 180, age: 30,
            sex: .male, activityLevel: .moderatelyActive
        )
        #expect(tdee == 2759)
    }

    @Test func calculateTDEE_sedentary() {
        // Male, 80kg, 180cm, age 30, sedentary: BMR 1780 * 1.2 = 2136
        let tdee = TDEECalculator.calculateTDEE(
            weightKg: 80, heightCm: 180, age: 30,
            sex: .male, activityLevel: .sedentary
        )
        #expect(tdee == 2136)
    }
}
