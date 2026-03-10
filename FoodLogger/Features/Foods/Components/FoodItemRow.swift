import SwiftUI

struct FoodItemRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body)

                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(food.caloriesPerServing.formattedCalories)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("per \(food.servingSize.formattedOneDecimal) \(food.servingUnit.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if food.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }
}
