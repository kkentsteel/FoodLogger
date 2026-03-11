import SwiftUI
import SwiftData
import PhotosUI
import Observation

@Observable
@MainActor
final class NutritionLabelScanViewModel {
    // State
    var scanState: LabelScanState = .ready
    var capturedImage: UIImage?
    var parsedNutrition: NutritionLabelParser.ParsedNutrition?
    var errorMessage: String?

    // Camera
    let cameraService = CameraService()
    let permissionManager = CameraPermissionManager()

    enum LabelScanState: Equatable {
        case ready          // Camera preview active
        case capturing      // Photo being taken
        case processing     // OCR running
        case result         // Nutrition parsed, show result
        case error
    }

    // MARK: - Setup

    func setupCamera() {
        guard permissionManager.isAuthorized else { return }

        do {
            try cameraService.configurePhotoCapture()
        } catch {
            errorMessage = error.localizedDescription
            scanState = .error
        }
    }

    func startSession() {
        let session = cameraService.captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() {
        let session = cameraService.captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Capture & Process

    func captureAndProcess() async {
        scanState = .capturing

        do {
            let image = try await cameraService.capturePhoto()
            capturedImage = image
            stopSession()
            await processImage(image)
        } catch {
            errorMessage = "Failed to capture: \(error.localizedDescription)"
            scanState = .error
        }
    }

    /// Process an image from the photo library.
    func processPickedImage(_ image: UIImage) async {
        capturedImage = image
        stopSession()
        await processImage(image)
    }

    private func processImage(_ image: UIImage) async {
        scanState = .processing

        do {
            let ocrService = OCRService()
            let textBlocks = try await ocrService.recognizeText(in: image)

            let parser = NutritionLabelParser()
            let nutrition = parser.parse(textBlocks: textBlocks)

            parsedNutrition = nutrition
            scanState = .result

            if nutrition.isUsable {
                HapticManager.success()
            } else {
                HapticManager.warning()
            }
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            scanState = .error
            HapticManager.error()
        }
    }

    // MARK: - Save

    @discardableResult
    func saveFoodItem(
        name: String,
        brand: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        context: ModelContext
    ) -> FoodItem? {
        let food = FoodItem(
            name: name,
            brand: brand,
            servingSize: 100,
            servingUnit: .grams,
            caloriesPerServing: calories,
            proteinPerServing: protein,
            carbsPerServing: carbs,
            fatPerServing: fat,
            fiberPerServing: fiber > 0 ? fiber : nil,
            source: .ocr
        )
        context.insert(food)
        try? context.save()
        HapticManager.success()
        return food
    }

    /// Saves the food item and logs it to today's first meal slot.
    func saveAndLogFoodItem(
        name: String,
        brand: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        context: ModelContext
    ) {
        guard let food = saveFoodItem(name: name, brand: brand, calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber, context: context) else { return }

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

    // MARK: - Reset

    func resetForNewScan() {
        scanState = .ready
        capturedImage = nil
        parsedNutrition = nil
        errorMessage = nil
        startSession()
    }
}
