import SwiftData
import Foundation

@MainActor
final class FoodDatabaseService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Food Queries

    func searchFoods(query: String, limit: Int = 50) throws -> [FoodItem] {
        let lowered = query.lowercased()
        let predicate = #Predicate<FoodItem> {
            $0.name.localizedStandardContains(lowered) ||
            ($0.brand?.localizedStandardContains(lowered) ?? false)
        }
        var descriptor = FetchDescriptor<FoodItem>(predicate: predicate, sortBy: [SortDescriptor(\FoodItem.name)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func recentFoods(limit: Int = 10) throws -> [FoodItem] {
        let predicate = #Predicate<FoodItem> { $0.lastUsedAt != nil }
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\FoodItem.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func frequentFoods(limit: Int = 10) throws -> [FoodItem] {
        let predicate = #Predicate<FoodItem> { $0.usageCount > 0 }
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\FoodItem.usageCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func favoriteFoods() throws -> [FoodItem] {
        let predicate = #Predicate<FoodItem> { $0.isFavorite }
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\FoodItem.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func findByBarcode(_ barcode: String) throws -> FoodItem? {
        let predicate = #Predicate<FoodItem> { $0.barcode == barcode }
        var descriptor = FetchDescriptor<FoodItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func findByMatvaretabellenId(_ id: String) throws -> FoodItem? {
        let predicate = #Predicate<FoodItem> { $0.matvaretabellenId == id }
        var descriptor = FetchDescriptor<FoodItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Look up multiple foods by their Matvaretabellen IDs, preserving the order of the input IDs
    func findByMatvaretabellenIds(_ ids: [String]) throws -> [FoodItem] {
        // Fetch each ID individually — avoids loading entire matvaretabellen table
        var lookup: [String: FoodItem] = [:]
        for id in Set(ids) {
            if let food = try findByMatvaretabellenId(id) {
                lookup[id] = food
            }
        }
        // Preserve ranking order from search
        return ids.compactMap { lookup[$0] }
    }

    func totalFoodCount() throws -> Int {
        let descriptor = FetchDescriptor<FoodItem>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Daily Log

    func getOrCreateDailyLog(for date: Date) throws -> DailyLog {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyLog> { $0.date == startOfDay }
        var descriptor = FetchDescriptor<DailyLog>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let newLog = DailyLog(date: startOfDay)
        modelContext.insert(newLog)
        try modelContext.save()
        return newLog
    }

    // MARK: - User Profile

    func getUserProfile() throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func getMealSlots() throws -> [MealSlot] {
        let descriptor = FetchDescriptor<MealSlot>(
            sortBy: [SortDescriptor(\MealSlot.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }
}
