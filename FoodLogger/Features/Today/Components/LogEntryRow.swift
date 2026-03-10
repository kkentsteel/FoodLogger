import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.subheadline)

                if let brand = entry.foodItem?.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.totalCalories.formattedCalories)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text("\(entry.quantity.formattedOneDecimal) serving")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let food = entry.foodItem {
                        Text("P:\(Int(food.proteinPerServing * entry.quantity)) C:\(Int(food.carbsPerServing * entry.quantity)) F:\(Int(food.fatPerServing * entry.quantity))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    HapticManager.mediumTap()
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
