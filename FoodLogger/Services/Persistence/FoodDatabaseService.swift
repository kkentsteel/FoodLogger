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
        var lookup: [String: FoodItem] = [:]
        for id in Set(ids) {
            if let food = try findByMatvaretabellenId(id) {
                lookup[id] = food
            }
        }
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

    func dailyLog(for date: Date) throws -> DailyLog? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyLog> { $0.date == startOfDay }
        var descriptor = FetchDescriptor<DailyLog>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func dailyLogs(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate.adding(days: 1))
        let predicate = #Predicate<DailyLog> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: predicate,
            sortBy: [SortDescriptor(\DailyLog.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Shared Food Logging

    /// Log a food item to a meal slot on a given date. Returns the created LogEntry.
    @discardableResult
    func logFood(_ food: FoodItem, quantity: Double, mealSlot: MealSlot, date: Date) throws -> LogEntry {
        let dailyLog = try getOrCreateDailyLog(for: date)

        let entry = LogEntry(quantity: quantity)
        entry.foodItem = food
        entry.mealSlot = mealSlot
        entry.dailyLog = dailyLog
        entry.captureSnapshot(from: food)

        food.usageCount += 1
        food.lastUsedAt = Date()
        food.updatedAt = Date()

        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }

    /// Copy all entries from one date to another.
    func copyEntries(from sourceDate: Date, to targetDate: Date) throws -> Int {
        guard let sourceLog = try dailyLog(for: sourceDate) else { return 0 }
        let targetLog = try getOrCreateDailyLog(for: targetDate)

        var count = 0
        for entry in sourceLog.entries {
            let newEntry = LogEntry(quantity: entry.quantity)
            newEntry.foodItem = entry.foodItem
            newEntry.mealSlot = entry.mealSlot
            newEntry.dailyLog = targetLog
            newEntry.snapshotFoodName = entry.snapshotFoodName
            newEntry.snapshotCaloriesPerServing = entry.snapshotCaloriesPerServing
            newEntry.snapshotProteinPerServing = entry.snapshotProteinPerServing
            newEntry.snapshotCarbsPerServing = entry.snapshotCarbsPerServing
            newEntry.snapshotFatPerServing = entry.snapshotFatPerServing
            newEntry.snapshotFiberPerServing = entry.snapshotFiberPerServing
            modelContext.insert(newEntry)
            count += 1
        }
        try modelContext.save()
        return count
    }

    // MARK: - Meal Slot Helpers

    /// Returns the most appropriate meal slot based on the current time of day.
    static func mealSlotForCurrentTime(from slots: [MealSlot]) -> MealSlot? {
        guard !slots.isEmpty else { return nil }
        let hour = Calendar.current.component(.hour, from: Date())
        let sorted = slots.sorted { $0.sortOrder < $1.sortOrder }

        // Map slot names to time ranges
        switch hour {
        case 0..<10: return sorted.first  // Breakfast
        case 10..<14: return sorted.count > 1 ? sorted[1] : sorted.first  // Lunch
        case 14..<17: return sorted.last   // Snack (last slot)
        default: return sorted.count > 2 ? sorted[2] : sorted.last  // Dinner
        }
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

    // MARK: - Data Export

    func exportAsCSV(from startDate: Date, to endDate: Date) throws -> String {
        let logs = try dailyLogs(from: startDate, to: endDate)
        var csv = "Date,Meal,Food,Quantity,Calories,Protein(g),Carbs(g),Fat(g)\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for log in logs {
            let dateStr = dateFormatter.string(from: log.date)
            for entry in log.entries.sorted(by: { ($0.mealSlot?.sortOrder ?? 0) < ($1.mealSlot?.sortOrder ?? 0) }) {
                let meal = entry.mealSlot?.name ?? "Unknown"
                let name = entry.displayName.replacingOccurrences(of: ",", with: ";")
                let qty = entry.quantity.formattedOneDecimal
                let cal = Int(entry.totalCalories)
                let pro = Int(entry.totalProtein)
                let carb = Int(entry.totalCarbs)
                let fat = Int(entry.totalFat)
                csv += "\(dateStr),\(meal),\(name),\(qty),\(cal),\(pro),\(carb),\(fat)\n"
            }
        }
        return csv
    }
}
