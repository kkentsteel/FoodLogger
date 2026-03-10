import Testing
import Foundation
@testable import FoodLogger

@Suite("LogEntry Tests")
struct LogEntryTests {

    @Test("Total macros calculated from quantity")
    func totalMacrosCalculation() {
        let food = FoodItem(
            name: "Rice",
            servingSize: 100,
            caloriesPerServing: 130,
            proteinPerServing: 2.7,
            carbsPerServing: 28,
            fatPerServing: 0.3
        )

        let entry = LogEntry(quantity: 2.0)
        entry.foodItem = food

        #expect(entry.totalCalories == 260)
        #expect(entry.totalProtein == 5.4)
        #expect(entry.totalCarbs == 56)
        #expect(entry.totalFat == 0.6)
    }

    @Test("Fractional quantity works correctly")
    func fractionalQuantity() {
        let food = FoodItem(
            name: "Bread",
            caloriesPerServing: 200,
            proteinPerServing: 8,
            carbsPerServing: 40,
            fatPerServing: 2
        )

        let entry = LogEntry(quantity: 0.5)
        entry.foodItem = food

        #expect(entry.totalCalories == 100)
        #expect(entry.totalProtein == 4)
        #expect(entry.totalCarbs == 20)
        #expect(entry.totalFat == 1)
    }

    @Test("Entry with no food item returns zero macros")
    func noFoodItemReturnsZero() {
        let entry = LogEntry(quantity: 1.0)

        #expect(entry.totalCalories == 0)
        #expect(entry.totalProtein == 0)
        #expect(entry.totalCarbs == 0)
        #expect(entry.totalFat == 0)
    }

    @Test("Default quantity is 1.0")
    func defaultQuantity() {
        let entry = LogEntry()
        #expect(entry.quantity == 1.0)
    }
}
