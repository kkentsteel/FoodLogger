import SwiftUI

struct CompactFoodRow: View {
    let food: CompactFood

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.foodName)
                    .font(.body)

                HStack(spacing: 8) {
                    Text("P: \(food.protein.formattedGrams)")
                    Text("C: \(food.carbs.formattedGrams)")
                    Text("F: \(food.fat.formattedGrams)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(food.kcal.formattedCalories)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("per 100 g")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }
}
