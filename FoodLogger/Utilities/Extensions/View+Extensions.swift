import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
