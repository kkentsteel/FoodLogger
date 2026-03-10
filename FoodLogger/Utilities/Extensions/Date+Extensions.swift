import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortFormatted: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var dayOfWeek: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
