import Foundation

struct TDEECalculator {
    /// Mifflin-St Jeor Equation
    /// Male:   BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age(years) + 5
    /// Female: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age(years) - 161
    static func calculateBMR(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex
    ) -> Double {
        let base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age)
        switch sex {
        case .male: return base + 5.0
        case .female: return base - 161.0
        }
    }

    static func calculateTDEE(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        activityLevel: ActivityLevel
    ) -> Int {
        let bmr = calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        return Int((bmr * activityLevel.multiplier).rounded())
    }
}
