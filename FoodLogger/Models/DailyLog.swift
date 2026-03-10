import SwiftData
import Foundation

@Model
final class DailyLog {
    @Attribute(.unique) var date: Date

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.dailyLog)
    var entries: [LogEntry]

    var createdAt: Date

    // Computed totals
    var totalCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    var totalProtein: Double {
        entries.reduce(0) { $0 + $1.totalProtein }
    }

    var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.totalCarbs }
    }

    var totalFat: Double {
        entries.reduce(0) { $0 + $1.totalFat }
    }

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.entries = []
        self.createdAt = Date()
    }
}
