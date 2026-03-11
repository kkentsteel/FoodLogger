import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            if viewModel.hasAPIKey {
                chatContent
            } else {
                noAPIKeyView
            }
        }
        .onAppear {
            viewModel.checkAPIKey()
            viewModel.loadMessages(context: modelContext)
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Empty state with suggested prompts
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            emptyStateView
                        }

                        // Chat messages
                        ForEach(viewModel.messages, id: \.id) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = message.content
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }
                        }

                        // Typing indicator
                        if viewModel.isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) {
                    scrollToBottom(proxy: proxy)
                }
            }

            // Input bar
            ChatInputBar(
                text: $viewModel.inputText,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.sendMessage(context: modelContext)
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        viewModel.clearChat(context: modelContext)
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("AI Nutrition Assistant")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Ask me about your nutrition, meals, and daily progress. I have access to your food log and targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            SuggestedPromptsView(prompts: viewModel.suggestedPrompts) { prompt in
                Task {
                    await viewModel.sendSuggestedPrompt(prompt, context: modelContext)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                Task {
                    await viewModel.retryLastMessage(context: modelContext)
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.systemOrange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - No API Key View

    private var noAPIKeyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("API Key Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your Claude API key in Profile > Manage API Key to enable the AI assistant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            NavigationLink {
                APIKeySettingsView()
            } label: {
                Text("Set Up API Key")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .navigationTitle("Chat")
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if viewModel.isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
