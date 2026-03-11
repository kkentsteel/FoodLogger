import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// UIKit share sheet wrapped for SwiftUI
struct ShareSheetView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let data = text.data(using: .utf8) ?? Data()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FoodLogger_Export.csv")
        try? data.write(to: tempURL)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
