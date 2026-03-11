import Foundation
import SwiftData

/// Builds a dynamic system prompt for Claude that includes
/// the user's profile, daily targets, today's logged foods, and remaining macros.
@MainActor
struct ClaudeSystemPromptBuilder {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func buildSystemPrompt() -> String {
        var sections: [String] = []

        // Preamble
        sections.append("""
        You are a helpful nutrition assistant inside the FoodLogger app. \
        You help users track their food, answer nutrition questions, \
        and give practical meal suggestions based on their actual logged data and goals.
        """)

        // Rules
        sections.append("""
        RULES:
        - Be concise and friendly. Use short paragraphs.
        - Use metric units (grams, kcal) unless the user asks otherwise.
        - Never diagnose medical conditions or prescribe medication.
        - When suggesting foods, prefer common items the user might have available.
        - Round numbers to whole values for readability.
        - If you don't know something, say so honestly.
        """)

        // User profile (fetched once)
        let profile = fetchUserProfile()
        if let profile {
            sections.append(buildProfileSection(profile))
            sections.append(buildTargetsSection(profile))
        }

        // Today's log
        if let dailyLog = fetchTodayLog() {
            let mealSlots = fetchMealSlots()
            sections.append(buildTodayLogSection(dailyLog, mealSlots: mealSlots))

            if let profile {
                sections.append(buildRemainingSection(dailyLog, profile: profile))
            }
        } else {
            sections.append("TODAY'S LOG:\nNo food logged yet today.")
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Sections

    private func buildProfileSection(_ profile: UserProfile) -> String {
        let sex = profile.biologicalSex.rawValue
        let activity = profile.activityLevel.rawValue
        let mode = profile.macroMode == .fullMacros ? "Full Macros" : "Calories Only"

        return """
        USER PROFILE:
        - Age: \(profile.age), Sex: \(sex), Weight: \(formatWeight(profile.weightKg)) kg, Height: \(formatHeight(profile.heightCm)) cm
        - Activity: \(activity), Tracking mode: \(mode)
        """
    }

    private func buildTargetsSection(_ profile: UserProfile) -> String {
        var lines = ["DAILY TARGETS:"]
        lines.append("- Calories: \(profile.targetCalories) kcal")

        if profile.macroMode == .fullMacros {
            if let protein = profile.targetProteinGrams {
                lines.append("- Protein: \(Int(protein))g")
            }
            if let carbs = profile.targetCarbsGrams {
                lines.append("- Carbs: \(Int(carbs))g")
            }
            if let fat = profile.targetFatGrams {
                lines.append("- Fat: \(Int(fat))g")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private func buildTodayLogSection(_ dailyLog: DailyLog, mealSlots: [MealSlot]) -> String {
        let dateString = Self.dateFormatter.string(from: dailyLog.date)

        var lines = ["TODAY'S LOG (\(dateString)):"]
        lines.append("Total consumed: \(Int(dailyLog.totalCalories)) kcal, \(Int(dailyLog.totalProtein))g protein, \(Int(dailyLog.totalCarbs))g carbs, \(Int(dailyLog.totalFat))g fat")

        // Group entries by meal slot
        let sortedSlots = mealSlots.sorted { $0.sortOrder < $1.sortOrder }

        for slot in sortedSlots {
            let slotEntries = dailyLog.entries.filter { $0.mealSlot?.name == slot.name }
            if slotEntries.isEmpty { continue }

            lines.append("")
            lines.append("\(slot.name):")
            for entry in slotEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let name = entry.displayName
                let qty = entry.quantity
                let cal = Int(entry.totalCalories)
                let p = Int(entry.totalProtein)
                let c = Int(entry.totalCarbs)
                let f = Int(entry.totalFat)
                lines.append("  - \(name): \(formatQuantity(qty))x serving (\(cal) kcal, \(p)g P, \(c)g C, \(f)g F)")
            }
        }

        // Any entries without a meal slot
        let unslottedEntries = dailyLog.entries.filter { $0.mealSlot == nil }
        if !unslottedEntries.isEmpty {
            lines.append("")
            lines.append("Other:")
            for entry in unslottedEntries {
                let name = entry.displayName
                let cal = Int(entry.totalCalories)
                lines.append("  - \(name): \(cal) kcal")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func buildRemainingSection(_ dailyLog: DailyLog, profile: UserProfile) -> String {
        var lines = ["REMAINING TODAY:"]

        let remainingCal = profile.targetCalories - Int(dailyLog.totalCalories)
        lines.append("- Calories remaining: \(remainingCal) kcal")

        if profile.macroMode == .fullMacros {
            if let protein = profile.targetProteinGrams {
                let remaining = Int(protein) - Int(dailyLog.totalProtein)
                lines.append("- Protein remaining: \(remaining)g")
            }
            if let carbs = profile.targetCarbsGrams {
                let remaining = Int(carbs) - Int(dailyLog.totalCarbs)
                lines.append("- Carbs remaining: \(remaining)g")
            }
            if let fat = profile.targetFatGrams {
                let remaining = Int(fat) - Int(dailyLog.totalFat)
                lines.append("- Fat remaining: \(remaining)g")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Data Fetching

    private func fetchUserProfile() -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchTodayLog() -> DailyLog? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyLog> { $0.date == startOfDay }
        var descriptor = FetchDescriptor<DailyLog>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchMealSlots() -> [MealSlot] {
        let descriptor = FetchDescriptor<MealSlot>(
            sortBy: [SortDescriptor(\MealSlot.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Formatting

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))" : String(format: "%.1f", kg)
    }

    private func formatHeight(_ cm: Double) -> String {
        cm.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(cm))" : String(format: "%.1f", cm)
    }

    private func formatQuantity(_ qty: Double) -> String {
        qty.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(qty))" : String(format: "%.1f", qty)
    }
}
