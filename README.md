# FoodLogger

An AI-powered iOS food tracking app with conversational AI, barcode scanning, nutrition label OCR, and macro/calorie tracking.

## Features

### Daily Food Logging
- Track calories and macronutrients (protein, carbs, fat, fiber)
- Configurable meal slots (Breakfast, Lunch, Dinner, Snack)
- Visual progress with calorie ring and macro progress bars
- Date navigation to review past days

### Food Database
- 2,100+ Norwegian foods from Matvaretabellen (auto-seeded on first launch)
- Manual food entry with full nutrition details
- Search, filter (recent, frequent, favorites), and browse
- Track food usage frequency for quick re-logging

### Barcode Scanning
- Scan EAN-13, EAN-8, and UPC-E barcodes
- Lookup pipeline: local database -> Open Food Facts API -> manual entry
- Editable fields before saving for accuracy

### Nutrition Label OCR
- Photograph nutrition labels or pick from photo library
- Bilingual text recognition (English and Norwegian)
- Automatic extraction of calories, protein, carbs, fat, fiber
- kJ to kcal conversion, OCR error correction, confidence scoring
- Editable results for manual correction

### AI Chat Assistant
- Conversational nutrition assistant powered by Claude
- Dynamic context: system prompt includes user profile, daily targets, today's full food log, and remaining macros
- Markdown-rendered responses
- Suggested conversation starters
- Persistent conversation history

### Profile & Targets
- Personal stats (age, weight, height, sex, activity level)
- TDEE calculator (Mifflin-St Jeor equation)
- Calorie-only or full macro tracking modes
- Configurable daily calorie and macro targets
- Meal slot management (add, rename, reorder, delete)

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 6
- No third-party dependencies

## Getting Started

### Build from Source

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
# Install XcodeGen (if not installed)
brew install xcodegen

# Generate the Xcode project
cd FoodLogger
xcodegen generate

# Open in Xcode
open FoodLogger.xcodeproj
```

Build and run on an iOS 17+ simulator or device.

### API Key Setup

The AI Chat feature requires a Claude API key:

1. Get an API key from [Anthropic](https://console.anthropic.com/)
2. In the app, go to **Profile > Manage API Key**
3. Enter your API key (stored securely in the iOS Keychain)

### First Launch

On first launch, FoodLogger will:
1. Show an onboarding flow to set up your profile
2. Seed the food database with 2,100+ Norwegian foods from [Matvaretabellen](https://www.matvaretabellen.no/)
3. Create default meal slots (Breakfast, Lunch, Dinner, Snack)

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Text Recognition | Apple Vision (VNRecognizeTextRequest) |
| Camera | AVFoundation (AVCaptureSession) |
| Barcode Detection | AVCaptureMetadataOutput |
| AI | Claude API (Messages endpoint) |
| Food Lookup | Open Food Facts API v2 |
| Food Seed Data | Matvaretabellen API |
| Secure Storage | iOS Keychain (Security framework) |
| Project Generator | XcodeGen |
| Testing | Swift Testing framework |

## Project Structure

```
FoodLogger/
├── App/                           # Entry point and root TabView
├── Features/
│   ├── Today/                     # Daily log, calorie ring, meal sections
│   ├── Foods/                     # Food database browser and editor
│   ├── Scan/                      # Barcode scanner + nutrition label OCR
│   ├── Chat/                      # AI assistant with Claude
│   └── Profile/                   # Settings, targets, onboarding
├── Models/                        # SwiftData models and enums
├── Services/
│   ├── Camera/                    # AVCaptureSession + permissions
│   ├── Barcode/                   # Barcode detection service
│   ├── OCR/                       # Vision text recognition + label parser
│   ├── Networking/                # API clients (Claude, OFF, Matvaretabellen)
│   ├── Persistence/               # Database queries and seed data
│   ├── Security/                  # Keychain wrapper
│   └── Nutrition/                 # TDEE and macro calculators
├── Utilities/                     # Constants and extensions
└── Resources/                     # Assets and seed data
```

## Testing

47 unit tests across 10 test suites covering models, services, and view models:

```bash
# Run unit tests
xcodebuild -project FoodLogger.xcodeproj -scheme FoodLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FoodLoggerTests test
```

### Test Suites

| Suite | Tests | Coverage |
|-------|-------|----------|
| TDEECalculatorTests | 4 | BMR/TDEE calculations for male/female |
| MacroCalculatorTests | 3 | Macro percentage calculations |
| UserProfileTests | 2 | Default and custom profile initialization |
| FoodItemTests | 4 | Nutrition math, per-gram calculations |
| LogEntryTests | 4 | Quantity-based nutrition totals |
| DailyLogTests | 3 | Date normalization, computed totals |
| TodayViewModelTests | 6 | Daily log CRUD, entry filtering |
| OpenFoodFactsServiceTests | 5 | API response decoding |
| NutritionLabelParserTests | 11 | EN/NO labels, kJ conversion, OCR cleaning |
| ClaudeAPIServiceTests | 7 | Request encoding, response decoding, errors |

## External APIs

### Claude Messages API
- **Endpoint:** `https://api.anthropic.com/v1/messages`
- **Model:** `claude-sonnet-4-20250514`
- **Used for:** AI nutrition assistant chat

### Open Food Facts v2
- **Endpoint:** `https://world.openfoodfacts.net/api/v2/product/{barcode}.json`
- **Used for:** Barcode food lookup (no API key required)

### Matvaretabellen
- **Endpoint:** `https://www.matvaretabellen.no/api/nb/foods.json`
- **Used for:** Seeding the food database with Norwegian foods on first launch

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## License

Private project.
