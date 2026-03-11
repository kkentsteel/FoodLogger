import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var weekLogs: [DailyLog] = []

    private var profile: UserProfile? { profiles.first }

    private var weekDates: [Date] {
        let today = Date().startOfDay
        return (0..<7).reversed().map { today.adding(days: -$0) }
    }

    var body: some View {
        List {
            if let profile {
                Section {
                    averageRow("Avg Calories", value: averageCalories, target: Double(profile.targetCalories), unit: "kcal")

                    if profile.macroMode == .fullMacros {
                        averageRow("Avg Protein", value: averageProtein, target: profile.targetProteinGrams ?? 0, unit: "g")
                        averageRow("Avg Carbs", value: averageCarbs, target: profile.targetCarbsGrams ?? 0, unit: "g")
                        averageRow("Avg Fat", value: averageFat, target: profile.targetFatGrams ?? 0, unit: "g")
                    }
                } header: {
                    Text("7-Day Averages")
                }

                Section {
                    ForEach(weekDates, id: \.self) { date in
                        dayRow(for: date, profile: profile)
                    }
                } header: {
                    Text("Daily Breakdown")
                }
            } else {
                ContentUnavailableView(
                    "No Profile",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Set up your profile to see weekly data.")
                )
            }
        }
        .navigationTitle("Weekly Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadWeekData() }
    }

    // MARK: - Computed

    private var daysWithData: Int {
        weekLogs.filter { ($0.entries.count) > 0 }.count
    }

    private var averageCalories: Double {
        guard daysWithData > 0 else { return 0 }
        return weekLogs.reduce(0) { $0 + $1.totalCalories } / Double(daysWithData)
    }

    private var averageProtein: Double {
        guard daysWithData > 0 else { return 0 }
        return weekLogs.reduce(0) { $0 + $1.totalProtein } / Double(daysWithData)
    }

    private var averageCarbs: Double {
        guard daysWithData > 0 else { return 0 }
        return weekLogs.reduce(0) { $0 + $1.totalCarbs } / Double(daysWithData)
    }

    private var averageFat: Double {
        guard daysWithData > 0 else { return 0 }
        return weekLogs.reduce(0) { $0 + $1.totalFat } / Double(daysWithData)
    }

    // MARK: - Views

    private func averageRow(_ label: String, value: Double, target: Double, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value)) / \(Int(target)) \(unit)")
                .foregroundColor(value <= target * 1.1 ? .secondary : .orange)
        }
    }

    private func dayRow(for date: Date, profile: UserProfile) -> some View {
        let log = weekLogs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let calories = log?.totalCalories ?? 0
        let target = Double(profile.targetCalories)
        let progress = target > 0 ? calories / target : 0

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.dayOfWeek)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(date.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if calories > 0 {
                ProgressView(value: min(progress, 1.0))
                    .frame(width: 60)

                Text("\(Int(calories)) kcal")
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Data

    private func loadWeekData() {
        let dbService = FoodDatabaseService(modelContext: modelContext)
        let startDate = Date().startOfDay.adding(days: -6)
        let endDate = Date().startOfDay.adding(days: 1)
        weekLogs = (try? dbService.dailyLogs(from: startDate, to: endDate)) ?? []
    }
}
