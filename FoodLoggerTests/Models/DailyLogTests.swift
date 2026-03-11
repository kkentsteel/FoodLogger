import Testing
import Foundation
@testable import FoodLogger

@Suite("DailyLog Tests")
struct DailyLogTests {

    @Test("Date is normalized to start of day")
    func dateNormalization() {
        let now = Date()
        let log = DailyLog(date: now)
        let startOfDay = Calendar.current.startOfDay(for: now)

        #expect(log.date == startOfDay)
    }

    @Test("Computed totals sum entries correctly")
    func computedTotals() {
        let log = DailyLog(date: Date())

        let food1 = FoodItem(
            name: "Egg",
            caloriesPerServing: 155,
            proteinPerServing: 13,
            carbsPerServing: 1.1,
            fatPerServing: 11
        )
        let food2 = FoodItem(
            name: "Toast",
            caloriesPerServing: 120,
            proteinPerServing: 4,
            carbsPerServing: 22,
            fatPerServing: 1
        )

        let entry1 = LogEntry(quantity: 2.0)
        entry1.foodItem = food1
        entry1.captureSnapshot(from: food1)
        entry1.dailyLog = log

        let entry2 = LogEntry(quantity: 1.0)
        entry2.foodItem = food2
        entry2.captureSnapshot(from: food2)
        entry2.dailyLog = log

        log.entries = [entry1, entry2]

        #expect(log.totalCalories == 430) // 155*2 + 120
        #expect(log.totalProtein == 30)   // 13*2 + 4
        #expect(log.totalCarbs == 24.2)   // 1.1*2 + 22
        #expect(log.totalFat == 23)       // 11*2 + 1
    }

    @Test("Empty log has zero totals")
    func emptyLogZeroTotals() {
        let log = DailyLog(date: Date())

        #expect(log.totalCalories == 0)
        #expect(log.totalProtein == 0)
        #expect(log.totalCarbs == 0)
        #expect(log.totalFat == 0)
    }
}
