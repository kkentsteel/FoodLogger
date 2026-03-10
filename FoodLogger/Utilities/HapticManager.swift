import UIKit

/// Centralized haptic feedback manager.
enum HapticManager {
    /// Light tap — used for UI interactions (selecting, toggling).
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium tap — used for confirmations (food logged, scan complete).
    static func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Success notification — used for achievements (target reached, scan success).
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification — used for alerts (approaching limit, OCR low confidence).
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification — used for failures (scan failed, API error).
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Selection tick — used for picker changes, stepper increments.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
