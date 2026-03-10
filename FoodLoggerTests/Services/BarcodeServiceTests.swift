import Testing
import Foundation
import AVFoundation
@testable import FoodLogger

@Suite("BarcodeService Tests")
struct BarcodeServiceTests {

    // MARK: - Supported Types

    @Test("Supports EAN-13, EAN-8, and UPC-E")
    func supportedTypes() {
        let types = BarcodeService.supportedTypes
        #expect(types.contains(.ean13))
        #expect(types.contains(.ean8))
        #expect(types.contains(.upce))
        #expect(types.count == 3)
    }

    @Test("Does not support non-food barcode types")
    func doesNotSupportNonFood() {
        let types = BarcodeService.supportedTypes
        #expect(!types.contains(.qr))
        #expect(!types.contains(.pdf417))
        #expect(!types.contains(.code128))
    }

    // MARK: - Initialization

    @Test("MetadataOutput exists after init")
    func metadataOutputExists() {
        let service = BarcodeService()
        #expect(service.metadataOutput is AVCaptureMetadataOutput)
    }

    @Test("Callback is nil by default")
    func callbackNilByDefault() {
        let service = BarcodeService()
        #expect(service.onBarcodeDetected == nil)
    }

    @Test("Callback can be set")
    func callbackCanBeSet() {
        let service = BarcodeService()
        var called = false

        service.onBarcodeDetected = { _ in
            called = true
        }

        // Invoke the callback directly to verify it was set
        service.onBarcodeDetected?("test")
        #expect(called)
    }

    // MARK: - Callback Invocation

    @Test("Callback receives barcode string")
    func callbackReceivesBarcode() {
        let service = BarcodeService()
        var receivedBarcode: String?

        service.onBarcodeDetected = { barcode in
            receivedBarcode = barcode
        }

        service.onBarcodeDetected?("7038010053252")
        #expect(receivedBarcode == "7038010053252")
    }

    @Test("Callback fires for different barcodes")
    func callbackMultipleBarcodes() {
        let service = BarcodeService()
        var barcodes: [String] = []

        service.onBarcodeDetected = { barcode in
            barcodes.append(barcode)
        }

        service.onBarcodeDetected?("1234567890123")
        service.onBarcodeDetected?("9876543210987")

        #expect(barcodes.count == 2)
        #expect(barcodes[0] == "1234567890123")
        #expect(barcodes[1] == "9876543210987")
    }

    // Note: Debounce logic is in the AVCaptureMetadataOutputObjectsDelegate
    // method which requires actual AVMetadataObjects to test. This is tested
    // via on-device integration testing rather than unit tests, since
    // AVMetadataMachineReadableCodeObject cannot be instantiated directly.
}
