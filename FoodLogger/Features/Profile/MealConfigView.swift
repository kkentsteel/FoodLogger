import SwiftUI
import SwiftData

struct MealConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    @State private var newMealName = ""
    @State private var showAddSheet = false

    private var sortedSlots: [MealSlot] {
        profile.mealSlots.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section("Meals") {
                ForEach(sortedSlots) { slot in
                    Label(slot.name, systemImage: slot.iconName)
                }
                .onDelete(perform: deleteSlots)
                .onMove(perform: moveSlots)
            }

            Section {
                Button("Add Meal") {
                    showAddSheet = true
                }
            }
        }
        .navigationTitle("Manage Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .alert("Add Meal", isPresented: $showAddSheet) {
            TextField("Meal Name", text: $newMealName)
            Button("Add") {
                addMealSlot()
            }
            Button("Cancel", role: .cancel) {
                newMealName = ""
            }
        }
    }

    private func addMealSlot() {
        guard !newMealName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let slot = MealSlot(
            name: newMealName.trimmingCharacters(in: .whitespaces),
            sortOrder: profile.mealSlots.count,
            iconName: "fork.knife"
        )
        slot.userProfile = profile
        modelContext.insert(slot)
        try? modelContext.save()
        newMealName = ""
    }

    private func deleteSlots(at offsets: IndexSet) {
        let slots = sortedSlots
        for index in offsets {
            modelContext.delete(slots[index])
        }
        try? modelContext.save()
        reorderSlots()
    }

    private func moveSlots(from source: IndexSet, to destination: Int) {
        var slots = sortedSlots
        slots.move(fromOffsets: source, toOffset: destination)
        for (index, slot) in slots.enumerated() {
            slot.sortOrder = index
        }
        try? modelContext.save()
    }

    private func reorderSlots() {
        for (index, slot) in sortedSlots.enumerated() {
            slot.sortOrder = index
        }
        try? modelContext.save()
    }
}
