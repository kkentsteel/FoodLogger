import SwiftUI

struct ParsedFoodItemRow: View {
    let item: FoodParsingService.ParsedFoodItem
    @Binding var isSelected: Bool
    @Binding var quantity: Double

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isSelected.toggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(!isSelected)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text("\(Int(item.estimatedCalories * quantity)) kcal")
                    Text("P:\(Int(item.estimatedProtein * quantity))g")
                    Text("C:\(Int(item.estimatedCarbs * quantity))g")
                    Text("F:\(Int(item.estimatedFat * quantity))g")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(item.estimatedServingSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Stepper(
                "\(quantity.formattedOneDecimal)",
                value: $quantity,
                in: 0.25...20,
                step: 0.25
            )
            .frame(width: 140)
            .disabled(!isSelected)
        }
        .padding(.vertical, 2)
    }
}
