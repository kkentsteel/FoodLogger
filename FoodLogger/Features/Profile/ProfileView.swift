import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealSlot.sortOrder) private var mealSlots: [MealSlot]
    @Query private var allFoods: [FoodItem]
    @Query private var allLogs: [DailyLog]
    @Query private var chatMessages: [ChatMessage]

    @State private var showDeleteFoodsConfirmation = false
    @State private var showDeleteLogsConfirmation = false
    @State private var showDeleteChatsConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { profiles.first }

    private var totalLogEntries: Int {
        allLogs.reduce(0) { $0 + $1.entries.count }
    }

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
                        LabeledContent("Foods in Database", value: "\(allFoods.count)")
                        LabeledContent("Daily Logs", value: "\(allLogs.count)")
                        LabeledContent("Log Entries", value: "\(totalLogEntries)")
                        LabeledContent("Chat Messages", value: "\(chatMessages.count)")
                    } header: {
                        Text("Data")
                    }

                    Section {
                        Button(role: .destructive) {
                            showDeleteFoodsConfirmation = true
                        } label: {
                            Label("Delete All Foods", systemImage: "fork.knife")
                        }
                        .disabled(allFoods.isEmpty)

                        Button(role: .destructive) {
                            showDeleteLogsConfirmation = true
                        } label: {
                            Label("Delete All Logs", systemImage: "calendar.badge.minus")
                        }
                        .disabled(allLogs.isEmpty)

                        Button(role: .destructive) {
                            showDeleteChatsConfirmation = true
                        } label: {
                            Label("Delete Chat History", systemImage: "bubble.left.and.bubble.right")
                        }
                        .disabled(chatMessages.isEmpty)

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                                .bold()
                        }
                        .disabled(allFoods.isEmpty && allLogs.isEmpty && chatMessages.isEmpty)
                    } header: {
                        Text("Data Management")
                    } footer: {
                        Text("Deleting foods will also remove any associated log entries.")
                    }
                }
                .navigationTitle("Profile")
                .confirmationDialog(
                    "Delete All Foods?",
                    isPresented: $showDeleteFoodsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(allFoods.count) Foods", role: .destructive) {
                        deleteAllFoods()
                    }
                } message: {
                    Text("This will delete all \(allFoods.count) foods and their associated log entries. This cannot be undone.")
                }
                .confirmationDialog(
                    "Delete All Logs?",
                    isPresented: $showDeleteLogsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(allLogs.count) Logs", role: .destructive) {
                        deleteAllLogs()
                    }
                } message: {
                    Text("This will delete all \(allLogs.count) daily logs and \(totalLogEntries) log entries. This cannot be undone.")
                }
                .confirmationDialog(
                    "Delete Chat History?",
                    isPresented: $showDeleteChatsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete \(chatMessages.count) Messages", role: .destructive) {
                        deleteAllChats()
                    }
                } message: {
                    Text("This will delete all \(chatMessages.count) chat messages. This cannot be undone.")
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

    // MARK: - Delete Actions

    private func deleteAllFoods() {
        do {
            for food in allFoods {
                modelContext.delete(food)
            }
            try modelContext.save()
            HapticManager.success()
        } catch {
            errorMessage = "Failed to delete foods: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllLogs() {
        do {
            for log in allLogs {
                modelContext.delete(log)
            }
            try modelContext.save()
            HapticManager.success()
        } catch {
            errorMessage = "Failed to delete logs: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllChats() {
        do {
            for message in chatMessages {
                modelContext.delete(message)
            }
            try modelContext.save()
            HapticManager.success()
        } catch {
            errorMessage = "Failed to delete chat history: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }

    private func deleteAllData() {
        do {
            for food in allFoods {
                modelContext.delete(food)
            }
            for log in allLogs {
                modelContext.delete(log)
            }
            for message in chatMessages {
                modelContext.delete(message)
            }
            try modelContext.save()
            HapticManager.success()
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            showError = true
            HapticManager.error()
        }
    }
}
