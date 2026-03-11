import SwiftData
import Foundation

@Model
final class MealSlot {
    var name: String
    var sortOrder: Int
    var iconName: String

    var userProfile: UserProfile?

    @Relationship(deleteRule: .nullify, inverse: \LogEntry.mealSlot)
    var logEntries: [LogEntry]

    init(name: String, sortOrder: Int, iconName: String = "fork.knife") {
        self.name = name
        self.sortOrder = sortOrder
        self.iconName = iconName
        self.logEntries = []
    }
}
