import SwiftUI

struct MacroBarView: View {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color

    private var rawProgress: Double {
        guard target > 0 else { return 0 }
        return consumed / target
    }

    private var clampedProgress: Double {
        min(rawProgress, 1.0)
    }

    private var isOver: Bool {
        rawProgress > 1.0
    }

    private var barColor: Color {
        isOver ? .red : color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(consumed))g / \(Int(target))g")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isOver ? .red : .primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * clampedProgress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: clampedProgress)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) progress")
        .accessibilityValue("\(Int(consumed)) of \(Int(target)) grams, \(Int(rawProgress * 100)) percent\(isOver ? ", over target" : "")")
    }
}
