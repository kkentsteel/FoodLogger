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
| Open Food Facts v2 | `OpenFoodFactsService` | Barcode lookup — `world.openfoodfacts.net/api/v2/product/{barcode}` |
| Matvaretabellen | `MatvaretabellenService` | Norwegian food DB seed — `matvaretabellen.no/api/nb/foods.json` |

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
