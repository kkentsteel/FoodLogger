import SwiftData
import Foundation
import Observation
import AVFoundation

@Observable
@MainActor
final class BarcodeScannerViewModel {
    // State
    var scanState: ScanState = .scanning
    var detectedBarcode: String?
    var scannedFood: ScannedFoodResult?
    var errorMessage: String?
    var isLookingUp = false
    var networkErrorOccurred = false
    var isTorchOn = false

    // Camera
    let cameraService = CameraService()
    let barcodeService = BarcodeService()
    let permissionManager = CameraPermissionManager()

    /// Model context for local DB lookups — set from the view.
    var modelContext: ModelContext?

    enum ScanState: Equatable {
        case scanning
        case found
        case notFound
        case error
    }

    /// Data from lookup, ready for user confirmation.
    struct ScannedFoodResult {
        var name: String
        var brand: String?
        var barcode: String
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double?
        var source: FoodSource
        var existingFoodItem: FoodItem?
    }

    // MARK: - Setup

    func setupCamera() {
        guard permissionManager.isAuthorized else { return }

        do {
            try cameraService.configureBarcodeScanning()
            try cameraService.addMetadataOutput(barcodeService.metadataOutput)
            barcodeService.configureMetadataTypes()

            barcodeService.onBarcodeDetected = { [weak self] barcode in
                Task { @MainActor in
                    self?.handleBarcodeDetected(barcode)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            scanState = .error
        }
    }

    func startScanning() {
        scanState = .scanning
        detectedBarcode = nil
        scannedFood = nil
        errorMessage = nil
        isLookingUp = false
        networkErrorOccurred = false

        let session = cameraService.captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopScanning() {
        let session = cameraService.captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Torch

    /// Toggles the camera torch (flashlight) on/off.
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchOn = true
            }
            device.unlockForConfiguration()
        } catch {
            // Silently fail — torch is non-critical
        }
    }

    // MARK: - Barcode Handling

    private func handleBarcodeDetected(_ barcode: String) {
        guard !isLookingUp else { return }
        detectedBarcode = barcode
        isLookingUp = true
        HapticManager.mediumTap()

        Task {
            await lookupBarcode(barcode, context: modelContext)
        }
    }

    /// Lookup pipeline: local DB -> Open Food Facts -> not found.
    private func lookupBarcode(_ barcode: String, context: ModelContext? = nil) async {
        networkErrorOccurred = false

        // Step 1: Check local database
        if let context {
            let dbService = FoodDatabaseService(modelContext: context)
            if let existing = try? dbService.findByBarcode(barcode) {
                scannedFood = ScannedFoodResult(
                    name: existing.name,
                    brand: existing.brand,
                    barcode: barcode,
                    calories: existing.caloriesPerServing,
                    protein: existing.proteinPerServing,
                    carbs: existing.carbsPerServing,
                    fat: existing.fatPerServing,
                    fiber: existing.fiberPerServing,
                    source: existing.source,
                    existingFoodItem: existing
                )
                scanState = .found
                isLookingUp = false
                HapticManager.success()
                stopScanning()
                return
            }
        }

        // Step 2: Look up on Open Food Facts
        do {
            let offService = OpenFoodFactsService()
            if let product = try await offService.lookupBarcode(barcode) {
                let data = product.asFoodData
                scannedFood = ScannedFoodResult(
                    name: data.name,
                    brand: data.brand,
                    barcode: barcode,
                    calories: data.calories,
                    protein: data.protein,
                    carbs: data.carbs,
                    fat: data.fat,
                    fiber: data.fiber,
                    source: .openFoodFacts
                )
                scanState = .found
                isLookingUp = false
                HapticManager.success()
                stopScanning()
                return
            }
        } catch {
            // Network error — track it so user can retry
            networkErrorOccurred = true
            errorMessage = error.localizedDescription
        }

        // Step 3: Not found (or network error — allow manual entry)
        scannedFood = ScannedFoodResult(
            name: "",
            brand: nil,
            barcode: barcode,
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            source: .barcode
        )
        scanState = .notFound
        isLookingUp = false
        HapticManager.warning()
        stopScanning()
    }

    /// Retry lookup for a previously detected barcode (e.g., after network failure).
    func retryLookup() {
        guard let barcode = detectedBarcode else { return }
        isLookingUp = true
        networkErrorOccurred = false
        errorMessage = nil
        Task {
            await lookupBarcode(barcode, context: modelContext)
        }
    }

    // MARK: - Save

    /// Saves the scanned food result to the database.
    @discardableResult
    func saveFood(context: ModelContext) -> FoodItem? {
        guard let result = scannedFood else { return nil }

        // If food already exists in DB, just return it
        if let existing = result.existingFoodItem {
            return existing
        }

        let food = FoodItem(
            name: result.name,
            brand: result.brand,
            barcode: result.barcode,
            servingSize: 100,
            servingUnit: .grams,
            caloriesPerServing: result.calories,
            proteinPerServing: result.protein,
            carbsPerServing: result.carbs,
            fatPerServing: result.fat,
            fiberPerServing: result.fiber,
            source: result.source
        )
        context.insert(food)
        try? context.save()
        HapticManager.success()
        return food
    }

    /// Saves the scanned food and logs it to the first available meal slot for today.
    func saveAndLogFood(context: ModelContext) {
        guard let food = saveFood(context: context) else { return }

        let dbService = FoodDatabaseService(modelContext: context)
        guard let dailyLog = try? dbService.getOrCreateDailyLog(for: Date()),
              let slots = try? dbService.getMealSlots(),
              let firstSlot = slots.sorted(by: { $0.sortOrder < $1.sortOrder }).first else {
            return
        }

        let entry = LogEntry(quantity: 1.0)
        entry.dailyLog = dailyLog
        entry.foodItem = food
        entry.mealSlot = firstSlot
        entry.captureSnapshot(from: food)
        context.insert(entry)
        food.usageCount += 1
        food.lastUsedAt = Date()
        try? context.save()
    }

    func resetForNewScan() {
        scanState = .scanning
        detectedBarcode = nil
        scannedFood = nil
        errorMessage = nil
        isLookingUp = false
        networkErrorOccurred = false
        // Turn off torch when resetting
        if isTorchOn {
            toggleTorch()
        }
        startScanning()
    }
}
