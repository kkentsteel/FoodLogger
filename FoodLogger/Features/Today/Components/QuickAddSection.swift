import SwiftUI
import SwiftData

/// Horizontal scrollable row of recent foods for quick one-tap logging.
struct QuickAddSection: View {
    let recentFoods: [FoodItem]
    let onQuickAdd: (FoodItem) -> Void

    var body: some View {
        if !recentFoods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentFoods) { food in
                            quickAddChip(for: food)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func quickAddChip(for food: FoodItem) -> some View {
        Button {
            onQuickAdd(food)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(Int(food.caloriesPerServing)) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
