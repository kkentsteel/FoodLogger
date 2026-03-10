import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class ChatViewModel {
    // State
    var messages: [ChatMessage] = []
    var inputText = ""
    var isLoading = false
    var errorMessage: String?
    var hasAPIKey = false

    // Services
    private let keychainService = KeychainService()
    private let claudeAPI = ClaudeAPIService()

    // Conversation history cap
    private let maxHistoryMessages = 20

    // MARK: - Setup

    func loadMessages(context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\ChatMessage.createdAt)]
        )

        if let fetched = try? context.fetch(descriptor) {
            messages = fetched
        }

        checkAPIKey()
    }

    func checkAPIKey() {
        hasAPIKey = (try? keychainService.retrieve(key: Constants.Keychain.claudeAPIKey)) != nil
    }

    // MARK: - Send Message

    func sendMessage(context: ModelContext) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isLoading else { return }

        // Clear input immediately
        inputText = ""
        errorMessage = nil

        // Create and persist user message
        let userMessage = ChatMessage(role: .user, content: text)
        context.insert(userMessage)
        messages.append(userMessage)
        try? context.save()
        HapticManager.lightTap()

        // Send to API
        isLoading = true

        do {
            guard let apiKey = try keychainService.retrieve(key: Constants.Keychain.claudeAPIKey) else {
                throw ChatError.noAPIKey
            }

            // Build dynamic system prompt
            let promptBuilder = ClaudeSystemPromptBuilder(modelContext: context)
            let systemPrompt = promptBuilder.buildSystemPrompt()

            // Build conversation history (capped)
            let history = buildConversationHistory()

            let responseText = try await claudeAPI.sendMessage(
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                messages: history
            )

            // Create and persist assistant message
            let assistantMessage = ChatMessage(role: .assistant, content: responseText)
            context.insert(assistantMessage)
            messages.append(assistantMessage)
            try? context.save()

        } catch let error as ClaudeAPIError {
            handleAPIError(error)
        } catch let error as ChatError {
            handleChatError(error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }

    // MARK: - Conversation History

    private func buildConversationHistory() -> [ClaudeMessage] {
        // Take the most recent messages, capped
        let recentMessages = messages.suffix(maxHistoryMessages)

        return recentMessages.map { msg in
            ClaudeMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.content
            )
        }
    }

    // MARK: - Clear Chat

    func clearChat(context: ModelContext) {
        for message in messages {
            context.delete(message)
        }
        messages.removeAll()
        try? context.save()
        errorMessage = nil
    }

    // MARK: - Error Handling

    private func handleAPIError(_ error: ClaudeAPIError) {
        switch error {
        case .invalidAPIKey:
            errorMessage = "Invalid API key. Please update your key in Profile > Manage API Key."
            hasAPIKey = false
        case .rateLimited:
            errorMessage = "Rate limited. Please wait a moment and try again."
        case .serverError:
            errorMessage = "Claude is temporarily unavailable. Try again later."
        case .emptyResponse:
            errorMessage = "Received an empty response. Please try again."
        default:
            errorMessage = error.localizedDescription
        }
    }

    private func handleChatError(_ error: ChatError) {
        switch error {
        case .noAPIKey:
            errorMessage = "No API key found. Add your key in Profile > Manage API Key."
            hasAPIKey = false
        }
    }

    // MARK: - Suggested Prompts

    var suggestedPrompts: [String] {
        [
            "What should I eat for dinner?",
            "Am I on track today?",
            "How much protein do I have left?",
            "Suggest a high-protein snack"
        ]
    }

    func sendSuggestedPrompt(_ prompt: String, context: ModelContext) async {
        inputText = prompt
        await sendMessage(context: context)
    }
}

// MARK: - Chat Errors

private enum ChatError: LocalizedError {
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured."
        }
    }
}
