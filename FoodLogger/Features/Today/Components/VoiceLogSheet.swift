import SwiftUI
import SwiftData

struct VoiceLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealSlot: MealSlot
    let date: Date

    @State private var inputText = ""
    @State private var parsedItems: [FoodParsingService.ParsedFoodItem] = []
    @State private var selectedStates: [UUID: Bool] = [:]
    @State private var quantities: [UUID: Double] = [:]
    @State private var isParsing = false
    @State private var showResults = false
    @State private var errorMessage: String?
    @State private var speechService = SpeechRecognitionService()

    var body: some View {
        NavigationStack {
            Group {
                if showResults {
                    resultsView
                } else {
                    inputView
                }
            }
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.stopRecording()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Input Phase

    private var inputView: some View {
        VStack(spacing: 20) {
            Text("Describe what you ate")
                .font(.headline)
                .padding(.top)

            Text("Type or use the microphone to describe your meal in natural language.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Microphone button
            Button {
                toggleRecording()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundColor(speechService.isRecording ? .red : .accentColor)
                        .frame(width: 72, height: 72)
                        .background(speechService.isRecording ? Color.red.opacity(0.15) : Color(.systemGray6))
                        .clipShape(Circle())
                        .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.isRecording)

                    Text(speechService.isRecording ? "Tap to stop" : "Tap to speak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Text input
            TextEditor(text: $inputText)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .onChange(of: speechService.transcript) { _, newValue in
                    if !newValue.isEmpty {
                        inputText = newValue
                    }
                }

            if let error = errorMessage ?? speechService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Text("e.g., \"I had 2 eggs, toast with butter, and a glass of orange juice\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                analyzeWithAI()
            } label: {
                if isParsing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Label("Analyze with AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Results Phase

    private var resultsView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(parsedItems) { item in
                        ParsedFoodItemRow(
                            item: item,
                            isSelected: Binding(
                                get: { selectedStates[item.id] ?? true },
                                set: { selectedStates[item.id] = $0 }
                            ),
                            quantity: Binding(
                                get: { quantities[item.id] ?? item.quantity },
                                set: { quantities[item.id] = $0 }
                            )
                        )
                    }
                } header: {
                    Text("Parsed Foods")
                } footer: {
                    let selected = parsedItems.filter { selectedStates[$0.id] ?? true }
                    let totalCal = selected.reduce(0) { $0 + $1.estimatedCalories * (quantities[$1.id] ?? $1.quantity) }
                    Text("Total: \(Int(totalCal)) kcal (\(selected.count) items)")
                }

                Section {
                    Button {
                        showResults = false
                        errorMessage = nil
                    } label: {
                        Label("Re-analyze", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            Button {
                logSelectedItems()
            } label: {
                Label("Log Selected", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let granted = await speechService.requestPermission()
                if granted {
                    do {
                        try speechService.startRecording()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func analyzeWithAI() {
        speechService.stopRecording()

        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let keychain = KeychainService()
        guard let apiKey = try? keychain.retrieve(key: Constants.Keychain.claudeAPIKey), !apiKey.isEmpty else {
            errorMessage = "No API key configured. Add your Claude API key in Settings."
            return
        }

        isParsing = true
        errorMessage = nil

        Task {
            do {
                let service = FoodParsingService()
                let items = try await service.parseFoodDescription(text, apiKey: apiKey)

                parsedItems = items
                for item in items {
                    selectedStates[item.id] = true
                    quantities[item.id] = item.quantity
                }
                showResults = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isParsing = false
        }
    }

    private func logSelectedItems() {
        let dbService = FoodDatabaseService(modelContext: modelContext)
        var loggedCount = 0

        for item in parsedItems {
            guard selectedStates[item.id] ?? true else { continue }
            let qty = quantities[item.id] ?? item.quantity

            let food = FoodItem(
                name: item.name,
                caloriesPerServing: item.estimatedCalories,
                proteinPerServing: item.estimatedProtein,
                carbsPerServing: item.estimatedCarbs,
                fatPerServing: item.estimatedFat
            )
            food.source = .aiParsed
            food.servingLabel = item.estimatedServingSize
            modelContext.insert(food)

            do {
                try dbService.logFood(food, quantity: qty, mealSlot: mealSlot, date: date)
                loggedCount += 1
            } catch {
                // Continue with remaining items
            }
        }

        if loggedCount > 0 {
            HapticManager.success()
        }
        dismiss()
    }
}
