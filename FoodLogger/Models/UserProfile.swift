import SwiftData
import Foundation

@Model
final class UserProfile {
    // Personal stats
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var biologicalSex: BiologicalSex
    var activityLevel: ActivityLevel

    // Targets
    var macroMode: MacroMode
    var targetCalories: Int
    var targetProteinGrams: Double?
    var targetCarbsGrams: Double?
    var targetFatGrams: Double?

    // Preferences
    var useMetricUnits: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \MealSlot.userProfile)
    var mealSlots: [MealSlot]

    init(
        age: Int = 30,
        weightKg: Double = 70.0,
        heightCm: Double = 170.0,
        biologicalSex: BiologicalSex = .male,
        activityLevel: ActivityLevel = .moderatelyActive,
        macroMode: MacroMode = .caloriesOnly,
        targetCalories: Int = 2000,
        targetProteinGrams: Double? = nil,
        targetCarbsGrams: Double? = nil,
        targetFatGrams: Double? = nil,
        useMetricUnits: Bool = true
    ) {
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
        self.macroMode = macroMode
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.targetFatGrams = targetFatGrams
        self.useMetricUnits = useMetricUnits
        self.createdAt = Date()
        self.updatedAt = Date()
        self.mealSlots = []
    }
}
