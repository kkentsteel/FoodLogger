import SwiftUI
import SwiftData

@main
struct FoodLoggerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                MealSlot.self,
                FoodItem.self,
                DailyLog.self,
                LogEntry.self,
                ChatMessage.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: FoodLoggerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
