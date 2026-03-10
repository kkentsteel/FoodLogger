import SwiftData
import Foundation

@Model
final class LogEntry {
    var quantity: Double
    var customServingSize: Double?
    var notes: String?

    var dailyLog: DailyLog?
    var foodItem: FoodItem?
    var mealSlot: MealSlot?

    var createdAt: Date
    var updatedAt: Date

    // Computed nutrition based on quantity
    var effectiveServingSize: Double {
        customServingSize ?? (foodItem?.servingSize ?? 0)
    }

    var totalCalories: Double {
        (foodItem?.caloriesPerServing ?? 0) * quantity
    }

    var totalProtein: Double {
        (foodItem?.proteinPerServing ?? 0) * quantity
    }

    var totalCarbs: Double {
        (foodItem?.carbsPerServing ?? 0) * quantity
    }

    var totalFat: Double {
        (foodItem?.fatPerServing ?? 0) * quantity
    }

    init(quantity: Double = 1.0, customServingSize: Double? = nil, notes: String? = nil) {
        self.quantity = quantity
        self.customServingSize = customServingSize
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
