import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]

    @State private var showDeleteFoodsConfirmation = false
    @State private var showDeleteLogsConfirmation = false
    @State private var showDeleteChatsConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var foodCount = 0
    @State private var logCount = 0
    @State private var entryCount = 0
    @State private var chatCount = 0

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            if let profile {
                List {
                    Section {
                        LabeledContent("Age", value: "\(profile.age)")
                        LabeledContent("Weight", value: "\(profile.weightKg.formattedOneDecimal) kg")
                        LabeledContent("Height", value: "\(profile.heightCm.formattedOneDecimal) cm")
                        LabeledContent("Sex", value: profile.biologicalSex.displayName)
                        LabeledContent("Activity", value: profile.activityLevel.displayName)

                        NavigationLink("Edit Profile") {
                            EditProfileView(profile: profile)
                        }
                    } header: {
                        Text("Personal Stats")
                    }

                    Section {
                        LabeledContent("Mode", value: profile.macroMode.displayName)
                        LabeledContent("Calories", value: "\(profile.targetCalories) kcal")

                        let tdee = TDEECalculator.calculateTDEE(
                            weightKg: profile.weightKg,
                            heightCm: profile.heightCm,
                            age: profile.age,
                            sex: profile.biologicalSex,
                            activityLevel: profile.activityLevel
                        )
                        LabeledContent("TDEE (calculated)", value: "\(tdee) kcal")

                        if profile.macroMode == .fullMacros {
                            LabeledContent("Protein", value: "\(Int(profile.targetProteinGrams ?? 0))g")
                            LabeledContent("Carbs", value: "\(Int(profile.targetCarbsGrams ?? 0))g")
                            LabeledContent("Fat", value: "\(Int(profile.targetFatGrams ?? 0))g")
                        }

                        NavigationLink("Edit Targets") {
                            TargetSettingsView(profile: profile)
                        }
                    } header: {
                        Text("Nutrition Targets")
                    }

                    Section {
                        ForEach(mealSlots) { slot in
                            Label(slot.name, systemImage: slot.iconName)
                        }
                        NavigationLink("Manage Meals") {
                            MealConfigView(profile: profile)
                        }
                    } header: {
                        Text("Meals")
                    }

                    Section {
                        NavigationLink("Manage API Key") {
                            APIKeySettingsView()
                        }
                    } header: {
                        Text("AI Assistant")
                    }

                    Section {
                        LabeledContent("Foods in Database", value: "\(foodCount)")
                        LabeledContent("Daily Logs", value: "\(logCount)")
                        LabeledContent("Log Entries", value: "\(entryCount)")
                        LabeledContent("Chat Messages", value: "\(chatCount)")
                    } header: {
                        Text("Data")
                    }

                    Section {
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    } header: {
                        Text("About")
                    } footer: {
                        Text("FoodLogger — AI-powered nutrition tracking. Food data from Matvaretabellen (matvaretabellen.no) and Open Food Facts.")
                    }

                    Section {
                        Button(role: .destructive) {
                            showDeleteFoodsConfirmation = true
                        } label: {
                            Label("Delete All Foods", systemImage: "fork.knife")
                        }
                        .disabled(foodCount == 0)

                        Button(role: .destructive) {
                            showDeleteLogsConfirmation = true
                        } label: {
                            Label("Delete All Logs", systemImage: "calendar.badge.minus")
                        }
                        .disabled(logCount == 0)

                        Button(role: .destructive) {
                            showDeleteChatsConfirmation = true
                        } label: {
                            Label("Delete Chat History", systemImage: "bubble.left.and.bubble.right")
                        }
                        .disabled(chatCount == 0)

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                                .bold()
                        }
                        .disabled(foodCount == 0 && logCount == 0 && chatCount == 0)
                    } header: {
                        Text("Data Management")
                    } footer: {
                        Text("Deleting foods will also remove any associated log entries.")
                    }
                }
                .navigationTitle("Profile")
                .onAppear { refreshCounts() }
                .confirmationDialog(
                    "Delete All Foods?",
                    isPresented: $showDeleteFoodsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(foodCount) Foods", role: .destructive) {
                        deleteAllFoods()
                    }
                } message: {
                    Text("This will delete all \(foodCount) foods. This cannot be undone.")
                }
                .confirmationDialog(
                    "Delete All Logs?",
                    isPresented: $showDeleteLogsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(logCount) Logs", role: .destructive) {
                        deleteAllLogs()
                    }
                } message: {
                    Text("This will delete all \(logCount) daily logs and \(entryCount) log entries. This cannot be undone.")
                }
                .confirmationDialog(
                    "Delete Chat History?",
                    isPresented: $showDeleteChatsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(chatCount) Messages", role: .destructive) {
                        deleteAllChats()
                    }
                } message: {
                    Text("This will delete all \(chatCount) chat messages. This cannot be undone.")
                }
                .confirmationDialog(
                    "Delete All Data?",
                    isPresented: $showDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        deleteAllData()
                    }
                } message: {
                    Text("This will delete all foods, logs, and chat messages. Your profile and meal slots will be kept. This cannot be undone.")
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            } else {
                ContentUnavailableView(
                    "No Profile",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Complete the setup to get started.")
                )
                .navigationTitle("Profile")
            }
        }
    }

    // MARK: - Counts

    private func refreshCounts() {
        foodCount = (try? modelContext.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
        logCount = (try? modelContext.fetchCount(FetchDescriptor<DailyLog>())) ?? 0
        entryCount = (try? modelContext.fetchCount(FetchDescriptor<LogEntry>())) ?? 0
        chatCount = (try? modelContext.fetchCount(FetchDescriptor<ChatMessage>())) ?? 0
    }

    // MARK: - Delete Actions

    private func deleteAllFoods() {
        do {
            try modelContext.delete(model: FoodItem.self)
            try modelContext.save()
            HapticManager.success()
            refreshCounts()
        } catch {
            errorMessage = "Failed to delete foods: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllLogs() {
        do {
            // Delete log entries first (since DailyLog cascade will handle its own,
            // but orphaned entries from nullified food/meal relationships need cleanup)
            try modelContext.delete(model: LogEntry.self)
            try modelContext.delete(model: DailyLog.self)
            try modelContext.save()
            HapticManager.success()
            refreshCounts()
        } catch {
            errorMessage = "Failed to delete logs: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllChats() {
        do {
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.save()
            HapticManager.success()
            refreshCounts()
        } catch {
            errorMessage = "Failed to delete chat history: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: LogEntry.self)
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: DailyLog.self)
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.save()
            HapticManager.success()
            refreshCounts()
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }
}
