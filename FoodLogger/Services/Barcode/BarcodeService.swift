import AVFoundation
import Foundation

/// Handles barcode detection from camera metadata output.
final class BarcodeService: NSObject, @unchecked Sendable, AVCaptureMetadataOutputObjectsDelegate {
    let metadataOutput = AVCaptureMetadataOutput()

    /// Called when a barcode is detected.
    var onBarcodeDetected: (@Sendable (String) -> Void)?

    /// Supported barcode types for food products.
    static let supportedTypes: [AVMetadataObject.ObjectType] = [
        .ean13,
        .ean8,
        .upce
    ]

    private var lastDetectedBarcode: String?
    private var lastDetectionTime: Date = .distantPast

    /// Minimum interval between processing the same barcode (seconds).
    private let debounceInterval: TimeInterval = 2.0

    override init() {
        super.init()
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
    }

    /// Configures the metadata output for barcode types.
    /// Must be called after the output is added to the capture session.
    func configureMetadataTypes() {
        let available = metadataOutput.availableMetadataObjectTypes
        let supported = Self.supportedTypes.filter { available.contains($0) }
        metadataOutput.metadataObjectTypes = supported
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = metadataObject.stringValue,
              !barcode.isEmpty else {
            return
        }

        // Debounce: avoid rapid-fire callbacks for same barcode
        let now = Date()
        if barcode == lastDetectedBarcode && now.timeIntervalSince(lastDetectionTime) < debounceInterval {
            return
        }

        lastDetectedBarcode = barcode
        lastDetectionTime = now

        onBarcodeDetected?(barcode)
    }
}
