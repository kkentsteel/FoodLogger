import SwiftUI

struct DailySummaryCard: View {
    let profile: UserProfile
    let dailyLog: DailyLog?

    private var consumedCalories: Double {
        dailyLog?.totalCalories ?? 0
    }

    private var targetCalories: Double {
        Double(profile.targetCalories)
    }

    private var remainingCalories: Double {
        max(0, targetCalories - consumedCalories)
    }

    private var progress: Double {
        guard targetCalories > 0 else { return 0 }
        return min(consumedCalories / targetCalories, 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Calorie ring
            CalorieRingView(
                consumed: consumedCalories,
                target: targetCalories,
                progress: progress
            )
            .frame(height: 160)

            // Remaining
            Text("\(Int(remainingCalories)) kcal remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Macro bars (if full macros mode)
            if profile.macroMode == .fullMacros {
                VStack(spacing: 8) {
                    MacroBarView(
                        label: "Protein",
                        consumed: dailyLog?.totalProtein ?? 0,
                        target: profile.targetProteinGrams ?? 0,
                        color: .blue
                    )
                    MacroBarView(
                        label: "Carbs",
                        consumed: dailyLog?.totalCarbs ?? 0,
                        target: profile.targetCarbsGrams ?? 0,
                        color: .orange
                    )
                    MacroBarView(
                        label: "Fat",
                        consumed: dailyLog?.totalFat ?? 0,
                        target: profile.targetFatGrams ?? 0,
                        color: .pink
                    )
                }
            }
        }
        .cardStyle()
    }
}
