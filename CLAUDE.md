# CLAUDE.md — FoodLogger Project Instructions

This file provides context and instructions for Claude when working on this codebase.

## Project Overview

FoodLogger is an AI-powered iOS food tracking app built with SwiftUI and SwiftData. It features conversational AI (via the Claude API), barcode scanning, nutrition label OCR, and macro/calorie tracking with Norwegian food database integration.

## Tech Stack

- **Platform:** iOS 17+
- **Language:** Swift 6 (strict concurrency: minimal)
- **UI:** SwiftUI
- **Persistence:** SwiftData (`@Model`, `ModelContainer`, `ModelContext`)
- **Project generation:** XcodeGen (`/opt/homebrew/bin/xcodegen`, config: `project.yml`)
- **Testing:** Swift Testing framework (`import Testing`, `@Test`, `@Suite`, `#expect`)
- **Dependencies:** None — zero third-party packages

## Build & Run

```bash
# Regenerate Xcode project after adding/removing files
cd FoodLogger && /opt/homebrew/bin/xcodegen generate

# Build
xcodebuild -project FoodLogger.xcodeproj -scheme FoodLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run unit tests only
xcodebuild -project FoodLogger.xcodeproj -scheme FoodLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FoodLoggerTests test

# Run all tests (unit + UI)
xcodebuild -project FoodLogger.xcodeproj -scheme FoodLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

**Important:** Always run `xcodegen generate` after creating or deleting Swift files. XcodeGen auto-discovers source files from directory structure.

## Architecture

### Pattern: MVVM with @Observable

- **Views:** SwiftUI views, no business logic
- **ViewModels:** `@Observable @MainActor` classes — own the state and business logic
- **Models:** SwiftData `@Model` classes — persistent data layer
- **Services:** Pure Swift structs, `actor` types, or `@MainActor` classes

### Directory Structure

```
FoodLogger/
├── App/                    # App entry point, ContentView (TabView)
├── Features/               # Feature modules, each with View + ViewModel + Components/
│   ├── Today/              # Daily food log overview
│   ├── Foods/              # Food database CRUD
│   ├── Scan/               # Barcode + nutrition label scanning
│   ├── Chat/               # AI chat assistant
│   └── Profile/            # User settings, targets, API key
├── Models/                 # SwiftData @Model classes + Enums/ + Migration/
├── Services/               # Business logic services
│   ├── Camera/             # AVCaptureSession management
│   ├── Barcode/            # Barcode detection (EAN-13, EAN-8, UPC-E)
│   ├── OCR/                # Vision text recognition + nutrition label parsing
│   ├── Networking/         # Claude API, Open Food Facts, Matvaretabellen
│   ├── Persistence/        # FoodDatabaseService, SeedDataService
│   ├── Security/           # Keychain wrapper for API keys
│   └── Nutrition/          # TDEE/BMR calculator, macro calculator
├── Utilities/              # Constants, extensions (Date+, Double+, View+)
├── Resources/              # Assets.xcassets, seed JSON
└── Preview Content/        # SwiftUI preview helpers
```

## Key Conventions

### Swift 6 Concurrency

- Network services → `actor` (e.g., `ClaudeAPIService`, `OpenFoodFactsService`, `OCRService`)
- ViewModels → `@Observable @MainActor`
- `CameraService` → `@unchecked Sendable` (AVCaptureSession manages own threading)
- DTOs and request/response types → `Sendable` structs
- Camera session start/stop → `DispatchQueue.global(qos: .userInitiated)` with captured session reference (not `Task.detached` which causes actor isolation issues)

### SwiftData

- All models in `Models/` with `@Model` attribute
- Relationships use `@Relationship(deleteRule: .cascade, inverse: \...)`
- Unique constraints use `@Attribute(.unique)` — NOT `#Unique<>` (iOS 18+ only)
- `FetchDescriptor.fetchLimit` is a property, not a constructor parameter
- Schema and migration in `Models/Migration/`

### SwiftUI

- Use `.tabItem { Label() }` — NOT `Tab()` syntax (iOS 18+ only)
- Use `Section { } header: { } footer: { }` — NOT `Section("title") { } footer: { }`
- Use `.tint` — NOT `.foregroundStyle(.accent)` (doesn't exist)

### Testing

- Uses Swift Testing framework: `@Suite`, `@Test`, `#expect`
- Test files in `FoodLoggerTests/` mirror source structure: `Models/`, `Services/`, `ViewModels/`
- In-memory `ModelContainer` for SwiftData tests
- Swift Testing tests show `◇`/`✔` in xcodebuild output (not XCTest format)

## Data Models

| Model | Purpose |
|-------|---------|
| `UserProfile` | Age, weight, height, sex, activity level, macro targets, meal slots |
| `MealSlot` | Named meal (Breakfast, Lunch, etc.) with sort order and icon |
| `FoodItem` | Food with nutrition per serving, barcode, source, usage tracking |
| `DailyLog` | Date-unique container for a day's food entries |
| `LogEntry` | Links FoodItem to a DailyLog + MealSlot with quantity |
| `ChatMessage` | AI conversation message with role (user/assistant) |

### Relationships

```
UserProfile 1──* MealSlot
FoodItem    1──* LogEntry
DailyLog    1──* LogEntry
MealSlot    1──* LogEntry
```

## External APIs

| API | Service | Purpose |
|-----|---------|---------|
| Claude Messages API | `ClaudeAPIService` | AI chat — `api.anthropic.com/v1/messages` |
| Open Food Facts v2 | `OpenFoodFactsService` | Barcode lookup — `world.openfoodfacts.org/api/v2/product/{barcode}` |
| Matvaretabellen | `MatvaretabellenService` | Norwegian food DB — `matvaretabellen.no/api/nb/` |

### Claude Messages API (`ClaudeAPIService`)

**Type:** `actor` (thread-safe, works off main thread)

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:**
- `Content-Type: application/json`
- `x-api-key: <key from Keychain>`
- `anthropic-version: 2023-06-01`

**Request body (`ClaudeRequest`):**
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 4096,
  "system": "<dynamic prompt from ClaudeSystemPromptBuilder>",
  "messages": [{ "role": "user|assistant", "content": "..." }]
}
```

**Response (`ClaudeResponse`):**
```json
{
  "id": "msg_...",
  "content": [{ "type": "text", "text": "..." }],
  "stop_reason": "end_turn",
  "usage": { "input_tokens": 500, "output_tokens": 200 }
}
```

**Error handling:**
- 401 → `ClaudeAPIError.invalidAPIKey` (prompt user to check key)
- 429 → `ClaudeAPIError.rateLimited` (auto-retry with exponential backoff, max 2 retries)
- 5xx → `ClaudeAPIError.serverError` (auto-retry with exponential backoff)
- Other 4xx → parse `ClaudeErrorResponse.error.message`

**Retry strategy:** Exponential backoff — 1s, 2s delays, max 2 retries. Only retries on 429 and 5xx.

**API key storage:** Keychain via `KeychainService` (key: `"claude_api_key"`, service: `"com.foodlogger.app"`). Never stored in UserDefaults or logged.

**System prompt:** Built dynamically per message by `ClaudeSystemPromptBuilder`, which queries SwiftData for:
- User profile (age, sex, weight, height, activity level, tracking mode)
- Daily targets (calories, protein/carbs/fat if fullMacros mode)
- Today's logged foods grouped by meal slot (compact format: name, qty, kcal, P/C/F)
- Remaining macros/calories for the day

**Conversation history:** Last 20 `ChatMessage` records from SwiftData, sent as the `messages` array.

### Open Food Facts API (`OpenFoodFactsService`)

**Type:** `actor`

**Endpoint:** `GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json`

**Headers:**
- `User-Agent: FoodLogger/1.0` (required by OFF API policy)

**Barcode validation:** Must be digits-only, 7-14 characters (covers EAN-8, EAN-13, UPC-A, UPC-E).

**Response (`OFFResponse`):**
```json
{
  "status": 1,
  "product": {
    "product_name": "Granola Bar",
    "brands": "Nature Valley",
    "code": "1234567890123",
    "serving_size": "40g",
    "nutriments": {
      "energy-kcal_100g": 450,
      "proteins_100g": 8.5,
      "carbohydrates_100g": 62,
      "fat_100g": 18,
      "fiber_100g": 4.2
    }
  }
}
```

**Key behavior:**
- `status: 1` = product found, `status: 0` = not found (returns `nil`)
- All nutrient values are **per 100g** — the app stores them as-is with `servingSize: 100, servingUnit: .grams`
- `OFFProduct.asFoodData` convenience tuple converts the response for `FoodItem` creation
- Timeout: 15s request / 30s resource
- No auth required, no rate limiting documented (but include User-Agent per policy)

**Barcode scan pipeline:** Local DB lookup → OFF API → manual entry prompt.

### Matvaretabellen API (`MatvaretabellenService`)

**Type:** `actor` with singleton (`MatvaretabellenService.shared`)

The Norwegian Food Composition Table (Matvaretabellen) provides comprehensive nutrition data for ~3,300 Norwegian foods. The service uses three endpoints:

**1. Compact Foods — `GET https://www.matvaretabellen.no/api/nb/compact-foods.json`**

Returns all foods (~3,300) in a compact JSON format (~4.6MB raw, ~200KB gzipped). This is the primary data source.

```json
[{
  "id": "06.533",
  "foodGroupId": "06",
  "url": "/nb/matvarer/06.533",
  "foodName": "Brunost, G35",
  "energyKj": 1523,
  "energyKcal": 364,
  "ediblePart": 100,
  "constituents": {
    "Protein": { "quantity": [27.0] },
    "Fett": { "quantity": [29.0] },
    "Karbo": { "quantity": [3.5] },
    "Fiber": { "quantity": [0.0] },
    "Vit A": { "quantity": [315.0] },
    "Ca": { "quantity": [493.0] }
  }
}]
```

**Nutrient ID mapping** (keys in `constituents`):
| ID | Nutrient | Unit |
|----|----------|------|
| `Protein` | Protein | g |
| `Fett` | Total Fat | g |
| `Karbo` | Carbohydrates | g |
| `Fiber` | Dietary Fiber | g |
| `Mettet` | Saturated Fat | g |
| `Enumet` | Monounsaturated Fat | g |
| `Flerum` | Polyunsaturated Fat | g |
| `Trans` | Trans Fat | g |
| `Omega-3` | Omega-3 | g |
| `Omega-6` | Omega-6 | g |
| `Kolest` | Cholesterol | mg |
| `Mono+Di` | Sugar | g |
| `Sukker` | Added Sugar | g |
| `Stivel` | Starch | g |
| `NaCl` | Salt | g |
| `Vann` | Water | g |
| `Vit A` | Vitamin A | µg RAE |
| `Vit D` | Vitamin D | µg |
| `Vit E` | Vitamin E | mg |
| `Vit C` | Vitamin C | mg |
| `Vit B1` | Thiamin | mg |
| `Vit B2` | Riboflavin | mg |
| `Vit B6` | Vitamin B6 | mg |
| `Vit B12` | Vitamin B12 | µg |
| `Niacin` | Niacin | mg |
| `Folat` | Folate | µg |
| `Ca` | Calcium | mg |
| `Fe` | Iron | mg |
| `Mg` | Magnesium | mg |
| `K` | Potassium | mg |
| `Na` | Sodium | mg |
| `Zn` | Zinc | mg |
| `Se` | Selenium | µg |
| `P` | Phosphorus | mg |
| `Cu` | Copper | mg |
| `I` | Iodine | µg |

**`CompactConstituent.quantity`** is an array where the first element is the value. Values can be `Double` or `String` (e.g., `"Sp"` for trace amounts) — the `ConstituentValue` enum handles both. All values are **per 100g edible portion**.

**2. Search Index — `GET https://www.matvaretabellen.no/search/index/nb.json`**

Client-side search index for fast food lookup without filtering server-side.

```json
{
  "foodName": {
    "ost": { "06.533": 10, "06.534": 8 },
    "melk": { "01.101": 10, "01.102": 9 }
  },
  "foodNameEdgegrams": {
    "os": { "06.533": 5, "06.534": 4 },
    "mel": { "01.101": 5, "01.102": 4 }
  }
}
```

**Search algorithm:** Tokenize query → match against `foodName` (exact, score x10) and `foodNameEdgegrams` (prefix, score x1) → sum scores per food ID → return top N ranked IDs → look up `CompactFood` by ID.

**3. Food Groups — `GET https://www.matvaretabellen.no/api/nb/food-groups.json`**

```json
[{ "foodGroupId": "06", "name": "Ost", "parentId": null }]
```

Used to resolve `foodGroupId` from `CompactFood` into a display name (e.g., "Ost" → Cheese).

**Caching:** All three endpoints are cached in-memory for 1 hour (`cacheDuration = 3600`). The compact foods response also builds a `[String: CompactFood]` dictionary for O(1) ID lookups.

**Data flow:** Search query → `searchFoodIds()` via search index → `compactFoodsById[id]` for full nutrient data → create/update `FoodItem` in SwiftData.

### Keychain (`KeychainService`)

**Type:** `struct` (value type, no actor needed — Security framework is thread-safe)

Wraps iOS Keychain (`SecItem*`) for secure API key storage.

| Method | Purpose |
|--------|---------|
| `save(key:value:)` | Upsert — `SecItemAdd`, falls back to `SecItemUpdate` on duplicate |
| `retrieve(key:)` | `SecItemCopyMatching` → returns `String?` (`nil` if not found) |
| `delete(key:)` | `SecItemDelete` (no-op if not found) |

**Config:** Service identifier `"com.foodlogger.app"`, accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (device-only, no iCloud sync).

**Usage:** Only stores the Claude API key (`Constants.Keychain.claudeAPIKey = "claude_api_key"`). The key is entered via `SecureField` in `APIKeySettingsView` and never logged or displayed after entry.

## Implementation Status

- **Phase 1 (Foundation):** COMPLETE — Models, enums, TabView, profile, onboarding, TDEE
- **Phase 2 (Food Database):** COMPLETE — CRUD, search, seed data, Matvaretabellen
- **Phase 3 (Food Logging):** COMPLETE — Daily log, meal slots, calorie ring, macro bars
- **Phase 4 (Barcode Scanning):** COMPLETE — Camera, barcode detection, OFF lookup
- **Phase 5 (Nutrition Label OCR):** COMPLETE — Vision OCR, bilingual parser (EN/NO)
- **Phase 6 (AI Chat):** COMPLETE — Claude API, dynamic system prompt, chat UI
- **Phase 7 (Polish):** COMPLETE — Haptics, accessibility, torch toggle, Save & Log, error retry, 91 tests passing
- **Phase 8 (Final Production Polish):** COMPLETE — Error alerts, form validation feedback, empty states, localization (en/nb), custom launch screen, app icon SVG, 91 tests passing

## Common Pitfalls

1. **Always regenerate Xcode project** after file changes: `xcodegen generate`
2. **SourceKit diagnostics** ("Cannot find type X in scope") are indexing lag — build to verify
3. **Simulator:** Use `iPhone 17 Pro` — no iPhone 16 simulator is available
4. **Camera requires device** — scanner features won't work in Simulator
5. **API key** is stored in Keychain, never in code or UserDefaults
