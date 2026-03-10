# FoodLogger Architecture

## Design Principles

1. **Offline-first:** Core logging, food CRUD, OCR all work without network. Barcode scanning falls back to local DB. Chat shows an offline state.
2. **Zero dependencies:** No CocoaPods, SPM, or third-party frameworks. UIKit only where SwiftUI can't reach (camera preview via `UIViewControllerRepresentable`).
3. **Swift 6 concurrency safe:** All shared state is actor-isolated or MainActor-bound. Network services are actors. DTOs are Sendable structs.
4. **Feature-organized:** Each feature is self-contained with its own View, ViewModel, and Components.

---

## Application Layer

### Entry Point

```
FoodLoggerApp (@main)
  └── ModelContainer (schema: 6 models, migration plan)
  └── ContentView
        ├── OnboardingView (sheet, shown if no UserProfile exists)
        └── TabView (5 tabs)
              ├── TodayView
              ├── FoodsView
              ├── ScanTabView
              ├── ChatView
              └── ProfileView
```

### Navigation Flow

```
Tab 0: Today    → NavigationStack → AddFoodToMealSheet (.sheet)
Tab 1: Foods    → NavigationStack → FoodDetailView (push) → AddFoodView (push)
Tab 2: Scan     → Barcode/Label picker (inline)
                   ├── BarcodeScannerView → ScanResultView (.sheet)
                   └── NutritionLabelScanView → OCRResultView (.sheet)
Tab 3: Chat     → NavigationStack → ChatView (messages + input)
Tab 4: Profile  → NavigationStack
                   ├── EditProfileView (push)
                   ├── TargetSettingsView (push)
                   ├── MealConfigView (push)
                   └── APIKeySettingsView (push)
```

---

## Data Layer

### SwiftData Schema

Six `@Model` classes form the persistence layer:

```
┌─────────────┐     1:*     ┌───────────┐
│ UserProfile  │────────────▶│ MealSlot   │
└─────────────┘             └───────────┘
                                  │ 1:*
                                  ▼
┌─────────────┐     1:*     ┌───────────┐     *:1     ┌───────────┐
│  DailyLog   │────────────▶│ LogEntry   │◀───────────│ FoodItem   │
└─────────────┘             └───────────┘             └───────────┘

┌─────────────┐
│ ChatMessage  │  (standalone, no relationships)
└─────────────┘
```

**Delete rules:** All relationships use `.cascade` — deleting a parent deletes its children.

### Enums

| Enum | Cases | Used By |
|------|-------|---------|
| `MacroMode` | `caloriesOnly`, `fullMacros` | UserProfile |
| `ActivityLevel` | `sedentary` through `extraActive` (with TDEE multipliers) | UserProfile |
| `BiologicalSex` | `male`, `female` | UserProfile |
| `FoodSource` | `manual`, `barcode`, `ocr`, `openFoodFacts`, `seed`, `matvaretabellen` | FoodItem |
| `ServingUnit` | `grams`, `milliliters`, `pieces`, `cups`, `tablespoons`, `teaspoons`, `ounces`, `slices`, `portions` | FoodItem |
| `MessageRole` | `user`, `assistant` | ChatMessage |

### Migration

- `FoodLoggerSchemaV1` — initial versioned schema containing all 6 models
- `FoodLoggerMigrationPlan` — `SchemaMigrationPlan` with stages for future schema changes

---

## Service Layer

### Concurrency Model

| Service | Isolation | Reason |
|---------|-----------|--------|
| `ClaudeAPIService` | `actor` | Network I/O, thread-safe URLSession |
| `OpenFoodFactsService` | `actor` | Network I/O |
| `MatvaretabellenService` | `actor` | Network I/O |
| `OCRService` | `actor` | Vision framework processing |
| `FoodDatabaseService` | `@MainActor` | SwiftData ModelContext is MainActor-bound |
| `SeedDataService` | `@MainActor` | Uses ModelContext |
| `ClaudeSystemPromptBuilder` | `@MainActor` | Uses ModelContext |
| `CameraService` | `@unchecked Sendable` | AVCaptureSession manages its own thread safety |
| `BarcodeService` | `NSObject` | AVCaptureMetadataOutputObjectsDelegate |
| `CameraPermissionManager` | `@Observable @MainActor` | UI-bound permission state |
| `TDEECalculator` | `struct` (static methods) | Pure computation, no state |
| `MacroCalculator` | `struct` (static methods) | Pure computation, no state |
| `KeychainService` | `struct` | Synchronous Keychain operations |
| `NutritionLabelParser` | `struct` | Pure text parsing, no state |

### Camera Service

```
CameraService
  ├── AVCaptureSession
  │     ├── AVCaptureDeviceInput (.builtInWideAngleCamera)
  │     ├── AVCaptureMetadataOutput (barcode mode: .ean13, .ean8, .upce)
  │     └── AVCapturePhotoOutput (photo mode for OCR)
  ├── configureBarcodeScan()   — sets up metadata output
  ├── configurePhotoCapture()  — sets up photo output
  ├── capturePhoto() async     — takes photo, returns UIImage
  └── captureSession           — exposed for CameraPreviewView
```

### Barcode Scanning Pipeline

```
Camera preview → detect EAN-13/EAN-8/UPC-E → haptic + pause scanning (2s debounce)
  → Local DB lookup (FoodDatabaseService.findByBarcode)
    → Found: show ScanResultView with existing data
    → Not found: Open Food Facts API lookup
      → Found: show ScanResultView with API data (editable)
      → Not found: prompt manual entry
```

### OCR Label Pipeline

```
Camera preview → capture photo (or pick from library)
  → OCRService.recognizeText() → [RecognizedTextBlock]
  → NutritionLabelParser.parse():
      1. Clean text (OCR misreads: O→0, normalize decimals)
      2. Match bilingual keywords (EN + NO)
      3. Extract numeric values (rightmost number per line)
      4. Convert kJ → kcal if needed
      5. Score confidence (0.0-1.0)
  → If confidence >= 0.3: OCRResultView with editable pre-filled fields
  → If confidence < 0.3: low-confidence warning, fields still editable
```

### AI Chat System

```
User types message
  → ChatViewModel.sendMessage()
      → Persist user ChatMessage to SwiftData
      → ClaudeSystemPromptBuilder.buildSystemPrompt()
          → Fetch UserProfile (age, sex, weight, activity, tracking mode)
          → Fetch daily targets (calories, protein, carbs, fat)
          → Fetch today's DailyLog with entries grouped by MealSlot
          → Calculate remaining macros
          → Assemble system prompt string
      → Build conversation history (last 20 messages)
      → ClaudeAPIService.sendMessage(apiKey, systemPrompt, messages)
          → POST https://api.anthropic.com/v1/messages
          → Headers: x-api-key, anthropic-version: 2023-06-01
          → Body: model, max_tokens (1024), system, messages
      → Persist assistant ChatMessage to SwiftData
      → Display in ChatBubbleView with markdown rendering
```

### Seed Data Flow

```
App launch → SeedDataService.seedIfNeeded()
  → Check if FoodItem count == 0
  → Try API-first: MatvaretabellenService.fetchAllFoods()
      → Fetch https://www.matvaretabellen.no/api/nb/foods.json
      → Map 2,121 foods to FoodItem models
      → Insert into ModelContext
  → Fallback: Load norwegian_foods_seed.json from bundle
      → Decode SeedCategory/SeedFoodItem structs
      → Map to FoodItem models
      → Insert into ModelContext
```

---

## View Layer

### ViewModel Pattern

All ViewModels follow this pattern:

```swift
@Observable
@MainActor
final class SomeViewModel {
    // Published state (automatically tracked by @Observable)
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    // Methods that mutate state
    func loadData(context: ModelContext) { ... }
    func performAction(context: ModelContext) async { ... }
}
```

Views inject `ModelContext` from `@Environment(\.modelContext)` and pass it to ViewModel methods.

### Key UI Components

| Component | Location | Description |
|-----------|----------|-------------|
| `CalorieRingView` | Today/Components | Circular progress ring for daily calories |
| `MacroBarView` | Today/Components | Horizontal progress bar for a macro |
| `DailySummaryCard` | Today/Components | Combined calorie ring + macro bars |
| `MealSectionView` | Today/Components | Expandable meal slot with entries |
| `LogEntryRow` | Today/Components | Single food entry with inline macros |
| `ChatBubbleView` | Chat/Components | User (blue) / assistant (gray) message bubble |
| `ChatInputBar` | Chat/Components | Multi-line text field with send button |
| `TypingIndicatorView` | Chat/Components | Animated 3-dot loading indicator |
| `SuggestedPromptsView` | Chat/Components | Scrollable prompt chips |
| `CameraPreviewView` | Scan/Components | UIViewControllerRepresentable camera preview |
| `ScanOverlayView` | Scan/Components | Viewfinder rectangle with corner accents |
| `OCRResultView` | Scan/Components | Parsed nutrition with confidence indicator |

---

## Error Handling Strategy

### API Errors

| HTTP Status | Error | User Message |
|-------------|-------|-------------|
| 200 | Success | — |
| 401 | `invalidAPIKey` | "Invalid API key. Check your key in Profile settings." |
| 429 | `rateLimited` | "Rate limited. Please wait a moment and try again." |
| 400-499 | `apiError(message)` | Server error message or "API error (HTTP code)" |
| 500-599 | `serverError` | "Claude API is temporarily unavailable. Try again later." |

### Graceful Degradation

- **No API key:** Chat shows setup card with link to API Key settings
- **No network:** Barcode falls back to local DB only; chat shows error banner
- **OCR low confidence:** Fields remain editable; confidence indicator shows red/orange
- **No camera permission:** Shows friendly message with Settings link
- **Empty food database:** Seed service runs on first launch; empty states shown otherwise

---

## Security

- **API keys:** Stored exclusively in iOS Keychain via `KeychainService`; never in UserDefaults, code, or logs
- **No secrets in source:** All API endpoints are public constants; authentication is runtime-only
- **Input via SecureField:** API key entry uses `SecureField` (masked input)
- **No cloud sync:** `ModelConfiguration(cloudKitDatabase: .none)` — all data stays on-device

---

## Performance Considerations

- **Debounced search:** 300ms debounce on food search to avoid excessive queries
- **Fetch limits:** All `FetchDescriptor` queries use `fetchLimit` to avoid loading entire tables
- **Lazy rendering:** `LazyVStack` in chat and food lists for virtualized scrolling
- **Background camera:** Session start/stop on `DispatchQueue.global(qos: .userInitiated)`
- **Token budget:** Chat history capped at 20 messages; system prompt kept compact (~400 tokens)
