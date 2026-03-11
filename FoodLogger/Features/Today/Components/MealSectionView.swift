import SwiftUI

struct MealSectionView: View {
    let mealSlot: MealSlot
    let entries: [LogEntry]
    let onAddFood: () -> Void
    let onDeleteEntry: (LogEntry) -> Void
    var onEditEntry: ((LogEntry) -> Void)?

    @AppStorage private var isExpanded: Bool

    init(mealSlot: MealSlot, entries: [LogEntry], onAddFood: @escaping () -> Void, onDeleteEntry: @escaping (LogEntry) -> Void, onEditEntry: ((LogEntry) -> Void)? = nil) {
        self.mealSlot = mealSlot
        self.entries = entries
        self.onAddFood = onAddFood
        self.onDeleteEntry = onDeleteEntry
        self.onEditEntry = onEditEntry
        self._isExpanded = AppStorage(wrappedValue: true, "mealSection_\(mealSlot.name)_expanded")
    }

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
                        LogEntryRow(
                            entry: entry,
                            onEdit: onEditEntry != nil ? { onEditEntry?(entry) } : nil,
                            onDelete: { onDeleteEntry(entry) }
                        )
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
