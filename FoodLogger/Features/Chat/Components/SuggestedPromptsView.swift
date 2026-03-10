import SwiftUI

/// Horizontal scrollable chips of suggested conversation starters.
struct SuggestedPromptsView: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onSelect(prompt)
                        } label: {
                            Text(prompt)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
