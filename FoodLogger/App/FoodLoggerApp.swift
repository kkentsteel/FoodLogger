import SwiftUI
import SwiftData

@main
struct FoodLoggerApp: App {
    let modelContainer: ModelContainer

    init() {
        let allModels: [any PersistentModel.Type] = [
            UserProfile.self,
            MealSlot.self,
            FoodItem.self,
            DailyLog.self,
            LogEntry.self,
            ChatMessage.self,
            SavedMeal.self,
            SavedMealItem.self
        ]

        let schema = Schema(allModels)

        // Try creating container. If the existing store can't be migrated
        // (e.g., version metadata mismatch from VersionedSchema), delete
        // the store and create a fresh one.
        if let container = Self.makeContainer(schema: schema) {
            modelContainer = container
        } else {
            Self.deleteExistingStore()
            guard let container = Self.makeContainer(schema: schema) else {
                fatalError("Failed to create ModelContainer after store reset")
            }
            modelContainer = container
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    private static func makeContainer(schema: Schema) -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            print("ModelContainer creation failed: \(error)")
            return nil
        }
    }

    private static func deleteExistingStore() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let storeURL = appSupport.appending(path: "default.store")

        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path() + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
