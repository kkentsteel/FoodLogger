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
                                    do {
                                        try viewModel.deleteEntry(entry, context: modelContext)
                                        loadDailyLog()
                                    } catch {
                                        errorMessage = "Failed to delete entry: \(error.localizedDescription)"
                                        showError = true
                                        HapticManager.error()
                                    }
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
            .navigationTitle("Today")
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
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

            Text(dateLabel)
                .font(.headline)
                .contentTransition(.numericText())

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

    private func loadDailyLog() {
        viewModel.loadDailyLog(for: selectedDate, context: modelContext)
        let dbService = FoodDatabaseService(modelContext: modelContext)
        recentFoods = (try? dbService.recentFoods(limit: 8)) ?? []
    }

    /// Quick-log a food to the first meal slot with 1x serving.
    private func quickLogFood(_ food: FoodItem) {
        guard let firstSlot = mealSlots.first else {
            errorMessage = "No meal slots configured. Add meal slots in your profile settings."
            showError = true
            HapticManager.error()
            return
        }

        do {
            let dailyLog = viewModel.getOrCreateDailyLog(for: selectedDate, context: modelContext)
            let entry = LogEntry(quantity: 1.0)
            entry.foodItem = food
            entry.mealSlot = firstSlot
            entry.dailyLog = dailyLog
            entry.captureSnapshot(from: food)

            food.usageCount += 1
            food.lastUsedAt = Date()
            food.updatedAt = Date()

            modelContext.insert(entry)
            try modelContext.save()

            HapticManager.success()
            loadDailyLog()
        } catch {
            errorMessage = "Failed to log food: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }
}
