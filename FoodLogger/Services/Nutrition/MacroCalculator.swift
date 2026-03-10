import Foundation

struct MacroCalculator {
    struct MacroTargets {
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
    }

    /// Default macro split: 30% protein, 40% carbs, 30% fat
    static func calculateDefaultMacros(fromCalories calories: Int) -> MacroTargets {
        let cal = Double(calories)
        return MacroTargets(
            proteinGrams: (cal * 0.30 / 4.0).rounded(),   // 4 kcal per gram protein
            carbsGrams: (cal * 0.40 / 4.0).rounded(),     // 4 kcal per gram carbs
            fatGrams: (cal * 0.30 / 9.0).rounded()        // 9 kcal per gram fat
        )
    }
}
