import Testing
import Foundation
@testable import FoodLogger

@Suite("FoodItem Tests")
struct FoodItemTests {

    @Test("Default init creates food with expected values")
    func defaultInit() {
        let food = FoodItem(
            name: "Apple",
            caloriesPerServing: 52,
            proteinPerServing: 0.3,
            carbsPerServing: 14,
            fatPerServing: 0.2,
            fiberPerServing: 2.4
        )

        #expect(food.name == "Apple")
        #expect(food.servingSize == 100)
        #expect(food.servingUnit == .grams)
        #expect(food.caloriesPerServing == 52)
        #expect(food.proteinPerServing == 0.3)
        #expect(food.carbsPerServing == 14)
        #expect(food.fatPerServing == 0.2)
        #expect(food.fiberPerServing == 2.4)
        #expect(food.source == .manual)
        #expect(food.isFavorite == false)
        #expect(food.usageCount == 0)
        #expect(food.lastUsedAt == nil)
        #expect(food.brand == nil)
        #expect(food.barcode == nil)
    }

    @Test("Per-gram calculations are correct")
    func perGramCalculations() {
        let food = FoodItem(
            name: "Chicken Breast",
            servingSize: 150,
            caloriesPerServing: 248,
            proteinPerServing: 46.5,
            carbsPerServing: 0,
            fatPerServing: 5.4
        )

        #expect(food.caloriesPerGram > 1.65)
        #expect(food.caloriesPerGram < 1.66)
        #expect(food.proteinPerGram == 46.5 / 150)
        #expect(food.carbsPerGram == 0)
        #expect(food.fatPerGram == 5.4 / 150)
    }

    @Test("Per-gram returns zero for zero serving size")
    func perGramZeroServingSize() {
        let food = FoodItem(
            name: "Test",
            servingSize: 0,
            caloriesPerServing: 100,
            proteinPerServing: 10
        )

        #expect(food.caloriesPerGram == 0)
        #expect(food.proteinPerGram == 0)
        #expect(food.carbsPerGram == 0)
        #expect(food.fatPerGram == 0)
    }

    @Test("Matvaretabellen source food")
    func matvaretabellenSource() {
        let food = FoodItem(
            name: "Agurk, norsk, rå",
            caloriesPerServing: 9,
            proteinPerServing: 0.8,
            carbsPerServing: 1.3,
            fatPerServing: 0.0,
            source: .matvaretabellen
        )
        food.matvaretabellenId = "06.220"
        food.foodGroupId = "6.2"

        #expect(food.source == .matvaretabellen)
        #expect(food.matvaretabellenId == "06.220")
        #expect(food.foodGroupId == "6.2")
    }
}
