import SwiftData
import Foundation

@Model
final class SavedMealItem {
    var quantity: Double
    var savedMeal: SavedMeal?
    var foodItem: FoodItem?
    var createdAt: Date

    init(quantity: Double = 1.0) {
        self.quantity = quantity
        self.createdAt = Date()
    }
}
