import SwiftUI

struct MealSectionView: View {
    let mealSlot: MealSlot
    let entries: [LogEntry]
    let onAddFood: () -> Void
    let onDeleteEntry: (LogEntry) -> Void

    @State private var isExpanded = true

    private var sectionCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: mealSlot.iconName)
                        .foregroundStyle(.tint)
                    Text(mealSlot.name)
                        .font(.headline)
                    Spacer()
                    Text(sectionCalories.formattedCalories)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                if entries.isEmpty {
                    Text("Tap + to add food")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(entries) { entry in
                        LogEntryRow(entry: entry, onDelete: {
                            onDeleteEntry(entry)
                        })
                    }
                }

                Button(action: onAddFood) {
                    Label("Add Food", systemImage: "plus")
                        .font(.subheadline)
                }
                .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }
}
