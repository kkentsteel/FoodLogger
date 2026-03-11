import SwiftData
import Foundation

@Model
final class LogEntry {
    var quantity: Double
    var notes: String?

    // Snapshot fields — captured at creation so totals survive food deletion
    var snapshotFoodName: String?
    var snapshotCaloriesPerServing: Double
    var snapshotProteinPerServing: Double
    var snapshotCarbsPerServing: Double
    var snapshotFatPerServing: Double
    var snapshotFiberPerServing: Double?

    var dailyLog: DailyLog?
    var foodItem: FoodItem?
    var mealSlot: MealSlot?

    var createdAt: Date
    var updatedAt: Date

    // Computed nutrition based on quantity — always uses snapshots for historical accuracy
    var totalCalories: Double {
        snapshotCaloriesPerServing * quantity
    }

    var totalProtein: Double {
        snapshotProteinPerServing * quantity
    }

    var totalCarbs: Double {
        snapshotCarbsPerServing * quantity
    }

    var totalFat: Double {
        snapshotFatPerServing * quantity
    }

    var totalFiber: Double {
        (snapshotFiberPerServing ?? 0) * quantity
    }

    var displayName: String {
        foodItem?.name ?? snapshotFoodName ?? "Unknown Food"
    }

    init(quantity: Double = 1.0, notes: String? = nil) {
        self.quantity = quantity
        self.notes = notes
        self.snapshotCaloriesPerServing = 0
        self.snapshotProteinPerServing = 0
        self.snapshotCarbsPerServing = 0
        self.snapshotFatPerServing = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Set snapshot fields from a food item. Call this when creating a new entry.
    func captureSnapshot(from food: FoodItem) {
        snapshotFoodName = food.name
        snapshotCaloriesPerServing = food.caloriesPerServing
        snapshotProteinPerServing = food.proteinPerServing
        snapshotCarbsPerServing = food.carbsPerServing
        snapshotFatPerServing = food.fatPerServing
        snapshotFiberPerServing = food.fiberPerServing
    }
}
