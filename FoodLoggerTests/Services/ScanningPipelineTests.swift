import Testing
import Foundation
@testable import FoodLogger

@Suite("Scanning Pipeline Tests")
struct ScanningPipelineTests {

    // MARK: - ScannedFoodResult

    @Test("ScannedFoodResult initializes correctly")
    func scannedFoodResultInit() {
        let result = BarcodeScannerViewModel.ScannedFoodResult(
            name: "Chocolate Bar",
            brand: "TestBrand",
            barcode: "1234567890123",
            calories: 534,
            protein: 7.5,
            carbs: 57.2,
            fat: 30.1,
            fiber: 3.4,
            source: .openFoodFacts
        )

        #expect(result.name == "Chocolate Bar")
        #expect(result.brand == "TestBrand")
        #expect(result.barcode == "1234567890123")
        #expect(result.calories == 534)
        #expect(result.protein == 7.5)
        #expect(result.carbs == 57.2)
        #expect(result.fat == 30.1)
        #expect(result.fiber == 3.4)
        #expect(result.source == .openFoodFacts)
        #expect(result.existingFoodItem == nil)
    }

    @Test("ScannedFoodResult with nil optional fields")
    func scannedFoodResultNilOptionals() {
        let result = BarcodeScannerViewModel.ScannedFoodResult(
            name: "Unknown",
            brand: nil,
            barcode: "999",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            source: .barcode
        )

        #expect(result.brand == nil)
        #expect(result.fiber == nil)
        #expect(result.existingFoodItem == nil)
    }

    // MARK: - OCRError

    @Test("OCRError provides descriptive messages")
    func ocrErrorDescriptions() {
        let invalidImage = OCRError.invalidImage
        #expect(invalidImage.errorDescription != nil)
        #expect(invalidImage.errorDescription!.contains("image"))

        let recognitionFailed = OCRError.recognitionFailed(NSError(domain: "test", code: -1))
        #expect(recognitionFailed.errorDescription != nil)
        #expect(recognitionFailed.errorDescription!.contains("recognition"))
    }

    // MARK: - CameraError

    @Test("CameraError provides descriptive messages")
    func cameraErrorDescriptions() {
        #expect(CameraError.noCameraAvailable.errorDescription != nil)
        #expect(CameraError.cannotAddInput.errorDescription != nil)
        #expect(CameraError.cannotAddOutput.errorDescription != nil)
        #expect(CameraError.cannotCapturePhoto.errorDescription != nil)
    }

    // MARK: - NetworkError

    @Test("NetworkError provides descriptive messages")
    func networkErrorDescriptions() {
        #expect(NetworkError.invalidURL.errorDescription != nil)
        #expect(NetworkError.invalidResponse.errorDescription != nil)
        #expect(NetworkError.httpError(statusCode: 404).errorDescription!.contains("404"))
        #expect(NetworkError.noData.errorDescription != nil)
        #expect(NetworkError.networkUnavailable.errorDescription != nil)
        #expect(NetworkError.timeout.errorDescription != nil)
    }

    @Test("NetworkError httpError includes status code")
    func networkErrorStatusCode() {
        let error = NetworkError.httpError(statusCode: 503)
        #expect(error.errorDescription!.contains("503"))
    }

    // MARK: - RecognizedTextBlock

    @Test("RecognizedTextBlock stores text and confidence")
    func recognizedTextBlock() {
        let block = RecognizedTextBlock(
            text: "Calories 200",
            confidence: 0.95,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.1)
        )

        #expect(block.text == "Calories 200")
        #expect(block.confidence == 0.95)
        #expect(block.boundingBox.width == 1)
    }

    // MARK: - NutritionLabelParser.ParsedNutrition

    @Test("ParsedNutrition default values")
    func parsedNutritionDefaults() {
        let nutrition = NutritionLabelParser.ParsedNutrition(confidence: 0.5)
        #expect(nutrition.calories == nil)
        #expect(nutrition.protein == nil)
        #expect(nutrition.carbs == nil)
        #expect(nutrition.fat == nil)
        #expect(nutrition.fiber == nil)
        #expect(nutrition.servingSize == nil)
        #expect(nutrition.filledFieldCount == 0)
    }

    @Test("ParsedNutrition filledFieldCount counts all non-nil fields")
    func parsedNutritionFieldCount() {
        var nutrition = NutritionLabelParser.ParsedNutrition(confidence: 0.8)
        #expect(nutrition.filledFieldCount == 0)

        nutrition.calories = 200
        #expect(nutrition.filledFieldCount == 1)

        nutrition.protein = 10
        nutrition.carbs = 25
        #expect(nutrition.filledFieldCount == 3)

        nutrition.fat = 8
        nutrition.fiber = 3
        #expect(nutrition.filledFieldCount == 5)
    }

    // MARK: - OFFProduct Data Conversion

    @Test("OFFProduct handles serving size parsing")
    func offProductServingSize() {
        let product = OFFProduct(
            productName: "Müsli",
            brands: "Coop",
            code: "7038010053252",
            servingSize: "100g",
            nutriments: OFFNutriments(
                energyKcal100g: 380,
                proteins100g: 10,
                carbohydrates100g: 65,
                fat100g: 8,
                fiber100g: 7
            )
        )

        let data = product.asFoodData
        #expect(data.name == "Müsli")
        #expect(data.brand == "Coop")
        #expect(data.barcode == "7038010053252")
        #expect(data.calories == 380)
        #expect(data.protein == 10)
        #expect(data.carbs == 65)
        #expect(data.fat == 8)
        #expect(data.fiber == 7)
    }

    @Test("OFFProduct with partial nutriments")
    func offProductPartialNutriments() {
        let nutriments = OFFNutriments(
            energyKcal100g: 100,
            proteins100g: nil,
            carbohydrates100g: 20,
            fat100g: nil,
            fiber100g: nil
        )
        let product = OFFProduct(
            productName: "Simple Juice",
            brands: nil,
            code: "123",
            servingSize: nil,
            nutriments: nutriments
        )

        let data = product.asFoodData
        #expect(data.calories == 100)
        #expect(data.protein == 0) // nil defaults to 0
        #expect(data.carbs == 20)
        #expect(data.fat == 0)
        #expect(data.fiber == nil) // fiber keeps nil
    }

    // MARK: - ScanState

    @Test("BarcodeScannerViewModel ScanState equality")
    func scanStateEquality() {
        let scanning = BarcodeScannerViewModel.ScanState.scanning
        let found = BarcodeScannerViewModel.ScanState.found
        let notFound = BarcodeScannerViewModel.ScanState.notFound
        let error = BarcodeScannerViewModel.ScanState.error

        #expect(scanning == .scanning)
        #expect(found == .found)
        #expect(notFound != found)
        #expect(error == .error)
    }

    @Test("NutritionLabelScanViewModel LabelScanState equality")
    func labelScanStateEquality() {
        let ready = NutritionLabelScanViewModel.LabelScanState.ready
        let capturing = NutritionLabelScanViewModel.LabelScanState.capturing
        let processing = NutritionLabelScanViewModel.LabelScanState.processing
        let result = NutritionLabelScanViewModel.LabelScanState.result

        #expect(ready == .ready)
        #expect(capturing != processing)
        #expect(result == .result)
    }
}
