import UIKit

/// Centralized haptic feedback manager.
@MainActor
enum HapticManager {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Light tap — used for UI interactions (selecting, toggling).
    static func lightTap() {
        lightGenerator.impactOccurred()
    }

    /// Medium tap — used for confirmations (food logged, scan complete).
    static func mediumTap() {
        mediumGenerator.impactOccurred()
    }

    /// Success notification — used for achievements (target reached, scan success).
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Warning notification — used for alerts (approaching limit, OCR low confidence).
    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error notification — used for failures (scan failed, API error).
    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    /// Selection tick — used for picker changes, stepper increments.
    static func selection() {
        selectionGenerator.selectionChanged()
    }
}
