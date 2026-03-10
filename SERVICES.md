# FoodLogger Services Reference

Detailed API contracts and usage documentation for every service in the app.

---

## Camera & Scanning Services

### CameraService

**File:** `Services/Camera/CameraService.swift`
**Type:** `NSObject, @unchecked Sendable`

Manages `AVCaptureSession` for both barcode scanning and photo capture modes.

```swift
// Properties
var captureSession: AVCaptureSession    // Exposed for CameraPreviewView

// Barcode mode
func configureBarcodeScan() throws      // Sets up AVCaptureMetadataOutput
func startSession()                      // Start on background queue
func stopSession()                       // Stop on background queue

// Photo mode
func configurePhotoCapture() throws     // Sets up AVCapturePhotoOutput
func capturePhoto() async throws -> UIImage
```

**Notes:**
- Only one mode at a time (barcode OR photo)
- Session start/stop dispatched to `DispatchQueue.global(qos: .userInitiated)`
- Implements `AVCapturePhotoCaptureDelegate` for photo capture

### CameraPermissionManager

**File:** `Services/Camera/CameraPermissionManager.swift`
**Type:** `@Observable @MainActor`

```swift
var authorizationStatus: AVAuthorizationStatus
var isAuthorized: Bool      // computed
var isDenied: Bool          // computed

func requestPermission() async
```

### BarcodeService

**File:** `Services/Barcode/BarcodeService.swift`
**Type:** `NSObject, AVCaptureMetadataOutputObjectsDelegate`

```swift
var detectedBarcode: String?    // Published via @Observable or delegate

func attachToSession(_ session: AVCaptureSession) throws
func startScanning()
func stopScanning()
```

**Supported formats:** `.ean13`, `.ean8`, `.upce`
**Debounce:** 2-second cooldown between detections to prevent rapid-fire scans.

---

## OCR Services

### OCRService

**File:** `Services/OCR/OCRService.swift`
**Type:** `actor`

```swift
func recognizeText(in image: UIImage) async throws -> [RecognizedTextBlock]
```

**Configuration:**
- Recognition level: `.accurate`
- Languages: `["en", "nb"]` (English + Norwegian)
- Language correction: enabled

**Returns:** Array of `RecognizedTextBlock`:
```swift
struct RecognizedTextBlock: Sendable {
    let text: String
    let confidence: Float      // 0.0 to 1.0
    let boundingBox: CGRect    // Normalized Vision coordinates
}
```

### NutritionLabelParser

**File:** `Services/OCR/NutritionLabelParser.swift`
**Type:** `struct` (value type, no state)

```swift
func parse(textBlocks: [RecognizedTextBlock]) -> ParsedNutrition
func extractNumericValue(from text: String) -> Double?
func cleanText(_ text: String) -> String
```

**ParsedNutrition:**
```swift
struct ParsedNutrition: Sendable {
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var servingSize: String?
    var confidence: Double      // 0.0-1.0
    var isUsable: Bool          // confidence >= 0.3 && has calories or protein
    var filledFieldCount: Int   // 0-5
}
```

**Bilingual keyword support:**

| Nutrient | English Keywords | Norwegian Keywords |
|----------|------------------|--------------------|
| Calories | calories, energy, cal, kcal | energi, kalorier |
| Protein | protein | protein, proteiner |
| Carbs | total carbohydrate, carbs | karbohydrater, karbohydrat |
| Fat | total fat, fat | fett, totalt fett |
| Fiber | dietary fiber, fiber, fibre | fiber, kostfiber |

**Smart features:**
- Extracts rightmost number per line (avoids "per 100g" reference numbers)
- Comma decimal separator support (`12,5` → `12.5`)
- OCR misread correction (`O` → `0` in numeric contexts)
- kJ → kcal conversion (divides by 4.184 when value > 500 and line contains "kj")
- Excludes "saturated fat" and "trans fat" lines from fat matching

---

## Networking Services

### ClaudeAPIService

**File:** `Services/Networking/ClaudeAPIService.swift`
**Type:** `actor`

```swift
func sendMessage(
    apiKey: String,
    systemPrompt: String?,
    messages: [ClaudeMessage]
) async throws -> String
```

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Request headers:**
- `Content-Type: application/json`
- `x-api-key: {apiKey}`
- `anthropic-version: 2023-06-01`

**Request body:**
```json
{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "system": "...",
    "messages": [{"role": "user", "content": "..."}]
}
```

**Error handling:**

| Status | Error Case | Description |
|--------|-----------|-------------|
| 200 | Success | Decode response, return first text block |
| 401 | `invalidAPIKey` | Bad or expired API key |
| 429 | `rateLimited` | Too many requests |
| 400-499 | `apiError(msg)` | Client error with server message |
| 500-599 | `serverError` | Server-side failure |

**Timeouts:** Request: 60s, Resource: 120s

### ClaudeSystemPromptBuilder

**File:** `Services/Networking/ClaudeSystemPromptBuilder.swift`
**Type:** `@MainActor struct`

```swift
init(modelContext: ModelContext)
func buildSystemPrompt() -> String
```

**Dynamically includes:**
1. Preamble (role and behavior instructions)
2. Rules (concise, metric units, no medical advice)
3. User profile (age, sex, weight, height, activity level, tracking mode)
4. Daily targets (calories, and optionally protein/carbs/fat)
5. Today's food log grouped by meal slot (compact one-line-per-food format)
6. Remaining macros for the day

**System prompt is rebuilt on every API call** to reflect the latest logged data.

### OpenFoodFactsService

**File:** `Services/Networking/OpenFoodFactsService.swift`
**Type:** `actor`

```swift
func lookupBarcode(_ barcode: String) async throws -> OFFProduct?
```

**Endpoint:** `GET https://world.openfoodfacts.net/api/v2/product/{barcode}.json`

**Headers:** `User-Agent: FoodLogger/1.0`

**Returns:** `OFFProduct` with nested `OFFNutriments`:
```swift
struct OFFProduct {
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
}

struct OFFNutriments {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
}
```

**Helper:** `OFFProduct.asFoodData` converts to a flat tuple for easy FoodItem creation.

### MatvaretabellenService

**File:** `Services/Networking/MatvaretabellenService.swift`
**Type:** `actor`

```swift
func fetchAllFoods() async throws -> [MatvaretabellenFood]
```

**Endpoint:** `GET https://www.matvaretabellen.no/api/nb/foods.json`

**Data:** 2,121 Norwegian foods with:
- Name, food group ID
- Energy in kJ and kcal (per 100g)
- Constituents: Protein, Fett (fat), Karbo (carbs), Fiber
- Edible portions

**Used by:** `SeedDataService` to populate the food database on first launch.

### NetworkError

**File:** `Services/Networking/NetworkError.swift`

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int)
    case networkUnavailable
}
```

---

## Persistence Services

### FoodDatabaseService

**File:** `Services/Persistence/FoodDatabaseService.swift`
**Type:** `@MainActor final class`

```swift
init(modelContext: ModelContext)

// Food queries
func searchFoods(query: String, limit: Int = 50) throws -> [FoodItem]
func recentFoods(limit: Int = 10) throws -> [FoodItem]
func frequentFoods(limit: Int = 10) throws -> [FoodItem]
func favoriteFoods() throws -> [FoodItem]
func findByBarcode(_ barcode: String) throws -> FoodItem?
func findByMatvaretabellenId(_ id: String) throws -> FoodItem?
func totalFoodCount() throws -> Int

// Daily log
func getOrCreateDailyLog(for date: Date) throws -> DailyLog

// User data
func getUserProfile() throws -> UserProfile?
func getMealSlots() throws -> [MealSlot]
```

**Notes:**
- `searchFoods` uses `localizedStandardContains` for accent-insensitive matching
- All queries use `fetchLimit` for performance
- `getOrCreateDailyLog` normalizes date to start-of-day before querying

### SeedDataService

**File:** `Services/Persistence/SeedDataService.swift`
**Type:** `@MainActor`

```swift
init(modelContext: ModelContext)
func seedIfNeeded() async
```

**Strategy:** API-first, JSON-fallback:
1. Check if food database is empty
2. Try fetching from Matvaretabellen API (2,121 foods)
3. If API fails, load from bundled `norwegian_foods_seed.json`
4. Map to `FoodItem` models with source `.matvaretabellen` or `.seed`

---

## Security Services

### KeychainService

**File:** `Services/Security/KeychainService.swift`
**Type:** `struct`

```swift
init(service: String = "com.foodlogger.app")
func save(key: String, value: String) throws      // Upserts (add or update)
func retrieve(key: String) throws -> String?       // Returns nil if not found
func delete(key: String) throws                    // No-op if not found
```

**Used for:** Storing the Claude API key securely.
**Key constant:** `Constants.Keychain.claudeAPIKey` = `"claude_api_key"`

---

## Nutrition Services

### TDEECalculator

**File:** `Services/Nutrition/TDEECalculator.swift`
**Type:** `struct` (static methods)

```swift
static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> Double
static func calculateTDEE(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex, activityLevel: ActivityLevel) -> Int
```

**Equation:** Mifflin-St Jeor
- Male BMR: `10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5`
- Female BMR: `10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161`
- TDEE = BMR * activity level multiplier

### MacroCalculator

**File:** `Services/Nutrition/MacroCalculator.swift`
**Type:** `struct` (static methods)

Computes macro gram targets from calorie targets using percentage splits.

---

## Constants

**File:** `Utilities/Constants.swift`

```swift
enum Constants {
    enum Keychain {
        static let claudeAPIKey = "claude_api_key"
    }
    enum API {
        static let claudeEndpoint = "https://api.anthropic.com/v1/messages"
        static let claudeModel = "claude-sonnet-4-20250514"
        static let claudeVersion = "2023-06-01"
        static let claudeMaxTokens = 1024
        static let offBaseURL = "https://world.openfoodfacts.net/api/v2/product"
        static let offUserAgent = "FoodLogger/1.0"
        static let matvaretabellenFoodsURL = "https://www.matvaretabellen.no/api/nb/foods.json"
        static let matvaretabellenFoodGroupsURL = "https://www.matvaretabellen.no/api/nb/food-groups.json"
    }
    enum Defaults {
        static let defaultMealSlots: [(name: String, icon: String)] = [...]
        static let defaultCalorieTarget = 2000
        static let searchDebounceMilliseconds = 300
    }
}
```
