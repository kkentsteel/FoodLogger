import SwiftUI

struct ActionButtonsRow: View {
    let onBarcodeScan: () -> Void
    let onVoiceLog: () -> Void
    let onMealScan: () -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ActionButton(icon: "barcode.viewfinder", title: "Barcode", action: onBarcodeScan)
                ActionButton(icon: "mic.fill", title: "Voice Log", action: onVoiceLog)
                ActionButton(icon: "doc.text.viewfinder", title: "Meal Scan", action: onMealScan)
                ActionButton(icon: "flame", title: "Quick Add", action: onQuickAdd)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
