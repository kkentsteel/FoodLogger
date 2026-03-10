import Testing
@testable import FoodLogger

struct MacroCalculatorTests {
    @Test func defaultMacroSplit() {
        let macros = MacroCalculator.calculateDefaultMacros(fromCalories: 2000)
        // 30% protein: 2000 * 0.3 / 4 = 150g
        // 40% carbs: 2000 * 0.4 / 4 = 200g
        // 30% fat: 2000 * 0.3 / 9 = 67g
        #expect(macros.proteinGrams == 150)
        #expect(macros.carbsGrams == 200)
        #expect(macros.fatGrams == 67)
    }
}
