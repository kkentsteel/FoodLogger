import SwiftUI

struct CalorieRingView: View {
    let consumed: Double
    let target: Double
    let progress: Double

    private var overAmount: Int {
        max(0, Int(consumed) - Int(target))
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)

            // Progress ring — show full ring when over target
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progress > 1.0 ? Color.red : Color.green,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center text
            VStack(spacing: 4) {
                Text("\(Int(consumed))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(progress > 1.0 ? .red : .primary)

                if progress > 1.0 {
                    Text("+\(overAmount) over")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("of \(Int(target)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorie progress")
        .accessibilityValue("\(Int(consumed)) of \(Int(target)) calories consumed, \(Int(progress * 100)) percent\(progress > 1.0 ? ", over target by \(overAmount)" : "")")
    }
}
