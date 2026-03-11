import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()
    @State private var selectedDate = Date()
    @State private var showAddFoodSheet = false
    @State private var selectedMealSlot: MealSlot?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recentFoods: [FoodItem] = []
    @State private var showDatePicker = false
    @State private var entryToEdit: LogEntry?
    @State private var editQuantity: Double = 1.0
    @State private var undoEntry: LogEntry?
    @State private var showUndo = false

    @Query private var profiles: [UserProfile]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date navigation
                    dateNavigationBar

                    if let profile {
                        // Daily summary card
                        DailySummaryCard(
                            profile: profile,
                            dailyLog: viewModel.dailyLog
                        )
                        .padding(.horizontal)

                        // Copy yesterday button (when log is empty)
                        if viewModel.dailyLog == nil || (viewModel.dailyLog?.entries.isEmpty == true) {
                            Button {
                                copyPreviousDay()
                            } label: {
                                Label("Copy Yesterday's Log", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }

                        // Quick add (recent foods)
                        if !recentFoods.isEmpty {
                            QuickAddSection(recentFoods: recentFoods) { food in
                                quickLogFood(food)
                            }
                        }

                        // Meal sections
                        ForEach(mealSlots) { slot in
                            MealSectionView(
                                mealSlot: slot,
                                entries: viewModel.entriesForSlot(slot),
                                onAddFood: {
                                    selectedMealSlot = slot
                                    showAddFoodSheet = true
                                },
                                onDeleteEntry: { entry in
                                    deleteEntryWithUndo(entry)
                                },
                                onEditEntry: { entry in
                                    editQuantity = entry.quantity
                                    entryToEdit = entry
                                }
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        ContentUnavailableView(
                            "No Profile",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("Set up your profile to start tracking.")
                        )
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                loadDailyLog()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                copyPreviousDay()
                            } label: {
                                Label("Copy Previous Day", systemImage: "doc.on.doc")
                            }

                            NavigationLink {
                                WeeklySummaryView()
                            } label: {
                                Label("Weekly Summary", systemImage: "chart.bar")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }

                        NavigationLink {
                            ProfileView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .onChange(of: selectedDate) {
                loadDailyLog()
            }
            .onAppear {
                loadDailyLog()
            }
            .sheet(isPresented: $showAddFoodSheet, onDismiss: {
                loadDailyLog()
            }) {
                if let slot = selectedMealSlot {
                    AddFoodToMealSheet(mealSlot: slot, date: selectedDate)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $entryToEdit) { entry in
                editQuantitySheet(for: entry)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay(alignment: .bottom) {
                if showUndo {
                    undoBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 80)
                }
            }
        }
    }

    private var dateLabel: String {
        if selectedDate.isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return selectedDate.shortFormatted
        }
    }

    private var dateNavigationBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = selectedDate.adding(days: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous day")

            Spacer()

            Button {
                showDatePicker = true
            } label: {
                Text(dateLabel)
                    .font(.headline)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to pick a date")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = selectedDate.adding(days: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            .accessibilityLabel("Next day")
        }
        .padding(.horizontal)
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Edit Quantity Sheet

    private func editQuantitySheet(for entry: LogEntry) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(entry.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Stepper(value: $editQuantity, in: 0.25...20, step: 0.25) {
                    Text("\(editQuantity.formattedOneDecimal) servings")
                        .font(.headline)
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("\(Int(entry.snapshotCaloriesPerServing * editQuantity)) kcal")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Text("P: \((entry.snapshotProteinPerServing * editQuantity).formattedGrams)")
                        Text("C: \((entry.snapshotCarbsPerServing * editQuantity).formattedGrams)")
                        Text("F: \((entry.snapshotFatPerServing * editQuantity).formattedGrams)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { entryToEdit = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.quantity = editQuantity
                        entry.updatedAt = Date()
                        try? modelContext.save()
                        HapticManager.success()
                        entryToEdit = nil
                        loadDailyLog()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Undo Banner

    private var undoBanner: some View {
        HStack {
            Text("Entry deleted")
                .font(.subheadline)
            Spacer()
            Button("Undo") {
                restoreDeletedEntry()
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
        .padding(.horizontal)
    }

    // MARK: - Data Loading

    private func loadDailyLog() {
        viewModel.loadDailyLog(for: selectedDate, context: modelContext)
        let dbService = FoodDatabaseService(modelContext: modelContext)
        recentFoods = (try? dbService.recentFoods(limit: 8)) ?? []
    }

    // MARK: - Quick Log (time-based slot)

    private func quickLogFood(_ food: FoodItem) {
        let slot = FoodDatabaseService.mealSlotForCurrentTime(from: mealSlots) ?? mealSlots.first

        guard let slot else {
            errorMessage = "No meal slots configured. Add meal slots in your profile settings."
            showError = true
            HapticManager.error()
            return
        }

        let dbService = FoodDatabaseService(modelContext: modelContext)
        do {
            try dbService.logFood(food, quantity: 1.0, mealSlot: slot, date: selectedDate)
            HapticManager.success()
            loadDailyLog()
        } catch {
            errorMessage = "Failed to log food: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    // MARK: - Delete with Undo

    private func deleteEntryWithUndo(_ entry: LogEntry) {
        undoEntry = entry
        do {
            try viewModel.deleteEntry(entry, context: modelContext)
            loadDailyLog()
            HapticManager.mediumTap()

            withAnimation {
                showUndo = true
            }

            // Auto-dismiss undo after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation {
                    showUndo = false
                    undoEntry = nil
                }
            }
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func restoreDeletedEntry() {
        guard let entry = undoEntry else { return }

        // Re-insert if the entry was removed
        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()
        loadDailyLog()

        withAnimation {
            showUndo = false
            undoEntry = nil
        }
    }

    // MARK: - Copy Previous Day

    private func copyPreviousDay() {
        let previousDate = selectedDate.adding(days: -1)
        let dbService = FoodDatabaseService(modelContext: modelContext)

        do {
            let count = try dbService.copyEntries(from: previousDate, to: selectedDate)
            if count > 0 {
                HapticManager.success()
                loadDailyLog()
            } else {
                errorMessage = "No entries to copy from the previous day."
                showError = true
            }
        } catch {
            errorMessage = "Failed to copy entries: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }
}
