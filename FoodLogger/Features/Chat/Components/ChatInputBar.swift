import SwiftUI

/// Text field with send button for chat input.
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about nutrition...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button {
                onSend()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 34, height: 34)
                .background(canSend ? .blue : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !isLoading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
