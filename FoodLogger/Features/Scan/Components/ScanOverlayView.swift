import SwiftUI

/// Overlay shown on top of camera preview with a viewfinder rectangle.
struct ScanOverlayView: View {
    let instruction: String
    var isScanning: Bool = true

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Viewfinder rectangle
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isScanning ? Color.white : Color.green, lineWidth: 3)
                    .frame(width: 280, height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                    )
                    .overlay(
                        // Corner accents
                        cornersOverlay
                    )
                    .accessibilityHidden(true)

                // Instruction text
                Text(instruction)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityLabel(instruction)

                if isScanning {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Scanning")
                }

                Spacer()
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanner viewfinder. \(instruction)")
    }

    private var cornersOverlay: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let len: CGFloat = 24
            let lw: CGFloat = 4
            let color = isScanning ? Color.white : Color.green

            // Top-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: len))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: len, y: 0))
            }
            .stroke(color, lineWidth: lw)

            // Top-right
            Path { path in
                path.move(to: CGPoint(x: w - len, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: len))
            }
            .stroke(color, lineWidth: lw)

            // Bottom-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: h - len))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: len, y: h))
            }
            .stroke(color, lineWidth: lw)

            // Bottom-right
            Path { path in
                path.move(to: CGPoint(x: w - len, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - len))
            }
            .stroke(color, lineWidth: lw)
        }
    }
}
