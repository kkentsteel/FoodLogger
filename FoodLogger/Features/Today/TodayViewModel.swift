import SwiftData
import Foundation
import Observation

@Observable
@MainActor
final class TodayViewModel {
    var dailyLog: DailyLog?

    func loadDailyLog(for date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyLog> { $0.date == startOfDay }
        var descriptor = FetchDescriptor<DailyLog>(predicate: predicate)
        descriptor.fetchLimit = 1

        dailyLog = try? context.fetch(descriptor).first
    }

    func getOrCreateDailyLog(for date: Date, context: ModelContext) -> DailyLog {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyLog> { $0.date == startOfDay }
        var descriptor = FetchDescriptor<DailyLog>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newLog = DailyLog(date: startOfDay)
        context.insert(newLog)
        try? context.save()
        dailyLog = newLog
        return newLog
    }

    func deleteEntry(_ entry: LogEntry, context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }

    func entriesForSlot(_ slot: MealSlot) -> [LogEntry] {
        guard let entries = dailyLog?.entries else { return [] }
        return entries
            .filter { $0.mealSlot?.persistentModelID == slot.persistentModelID }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
