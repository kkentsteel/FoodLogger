import SwiftData
import Foundation

@Model
final class SavedMeal {
    var name: String
    var iconName: String

    @Relationship(deleteRule: .cascade, inverse: \SavedMealItem.savedMeal)
    var items: [SavedMealItem]

    var usageCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Totals

    var totalCalories: Double {
        items.reduce(0) { $0 + ($1.foodItem?.caloriesPerServing ?? 0) * $1.quantity }
    }

    var totalProtein: Double {
        items.reduce(0) { $0 + ($1.foodItem?.proteinPerServing ?? 0) * $1.quantity }
    }

    var totalCarbs: Double {
        items.reduce(0) { $0 + ($1.foodItem?.carbsPerServing ?? 0) * $1.quantity }
    }

    var totalFat: Double {
        items.reduce(0) { $0 + ($1.foodItem?.fatPerServing ?? 0) * $1.quantity }
    }

    init(name: String, iconName: String = "tray.fill") {
        self.name = name
        self.iconName = iconName
        self.items = []
        self.usageCount = 0
        self.lastUsedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
