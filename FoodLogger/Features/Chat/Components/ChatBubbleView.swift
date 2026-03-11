import SwiftUI

/// A single chat message bubble.
struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                formattedContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .foregroundStyle(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.role == .user ? "You said" : "Assistant said")
        .accessibilityValue(message.content)
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: message.createdAt)
    }

    @ViewBuilder
    private var formattedContent: some View {
        if message.role == .assistant {
            let options = AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
            if let attributed = try? AttributedString(markdown: message.content, options: options) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(message.content)
                    .textSelection(.enabled)
            }
        } else {
            Text(message.content)
        }
    }
}
