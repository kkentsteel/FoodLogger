import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry
    var onDelete: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
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
                    Text("\(entry.quantity.formattedOneDecimal) \(entry.quantity == 1.0 ? "serving" : "servings")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("P:\(Int(entry.totalProtein)) C:\(Int(entry.totalCarbs)) F:\(Int(entry.totalFat))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
