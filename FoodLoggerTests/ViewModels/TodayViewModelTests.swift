import Testing
import Foundation
import SwiftData
@testable import FoodLogger

@Suite("TodayViewModel Tests")
struct TodayViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            MealSlot.self,
            FoodItem.self,
            DailyLog.self,
            LogEntry.self,
            ChatMessage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("loadDailyLog returns nil when no log exists")
    @MainActor
    func loadDailyLogNil() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel()

        vm.loadDailyLog(for: Date(), context: context)
        #expect(vm.dailyLog == nil)
    }

    @Test("loadDailyLog finds existing log for date")
    @MainActor
    func loadDailyLogFindsExisting() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(date: today)
        context.insert(log)
        try context.save()

        let vm = TodayViewModel()
        vm.loadDailyLog(for: Date(), context: context)

        #expect(vm.dailyLog != nil)
        #expect(vm.dailyLog?.date == today)
    }

    @Test("getOrCreateDailyLog creates new log when none exists")
    @MainActor
    func getOrCreateCreatesNew() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel()

        let log = vm.getOrCreateDailyLog(for: Date(), context: context)
        #expect(log.date == Calendar.current.startOfDay(for: Date()))
        #expect(vm.dailyLog != nil)
    }

    @Test("getOrCreateDailyLog returns existing log")
    @MainActor
    func getOrCreateReturnsExisting() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = DailyLog(date: Date())
        context.insert(existing)
        try context.save()

        let vm = TodayViewModel()
        let log = vm.getOrCreateDailyLog(for: Date(), context: context)

        #expect(log.persistentModelID == existing.persistentModelID)
    }

    @Test("entriesForSlot filters correctly")
    @MainActor
    func entriesForSlotFilters() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let profile = UserProfile()
        context.insert(profile)

        let slot1 = MealSlot(name: "Breakfast", sortOrder: 0, iconName: "sunrise")
        slot1.userProfile = profile
        let slot2 = MealSlot(name: "Lunch", sortOrder: 1, iconName: "sun.max")
        slot2.userProfile = profile
        context.insert(slot1)
        context.insert(slot2)

        let log = DailyLog(date: Date())
        context.insert(log)

        let food = FoodItem(name: "Egg", caloriesPerServing: 155, proteinPerServing: 13)
        context.insert(food)

        let entry1 = LogEntry(quantity: 2)
        entry1.foodItem = food
        entry1.mealSlot = slot1
        entry1.dailyLog = log
        context.insert(entry1)

        let entry2 = LogEntry(quantity: 1)
        entry2.foodItem = food
        entry2.mealSlot = slot2
        entry2.dailyLog = log
        context.insert(entry2)

        try context.save()

        let vm = TodayViewModel()
        vm.dailyLog = log

        let breakfastEntries = vm.entriesForSlot(slot1)
        let lunchEntries = vm.entriesForSlot(slot2)

        #expect(breakfastEntries.count == 1)
        #expect(breakfastEntries.first?.quantity == 2)
        #expect(lunchEntries.count == 1)
        #expect(lunchEntries.first?.quantity == 1)
    }

    @Test("deleteEntry removes entry")
    @MainActor
    func deleteEntryRemoves() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let log = DailyLog(date: Date())
        context.insert(log)

        let food = FoodItem(name: "Toast", caloriesPerServing: 120)
        context.insert(food)

        let entry = LogEntry(quantity: 1)
        entry.foodItem = food
        entry.dailyLog = log
        context.insert(entry)
        try context.save()

        let vm = TodayViewModel()
        try vm.deleteEntry(entry, context: context)

        let descriptor = FetchDescriptor<LogEntry>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }
}
