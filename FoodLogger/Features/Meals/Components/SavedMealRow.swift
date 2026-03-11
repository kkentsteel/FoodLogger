import SwiftUI

struct SavedMealRow: View {
    let meal: SavedMeal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(meal.items.count) item\(meal.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(meal.totalCalories)) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
