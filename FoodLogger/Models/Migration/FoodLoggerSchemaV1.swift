import SwiftData

enum FoodLoggerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            MealSlot.self,
            FoodItem.self,
            DailyLog.self,
            LogEntry.self,
            ChatMessage.self
        ]
    }
}
