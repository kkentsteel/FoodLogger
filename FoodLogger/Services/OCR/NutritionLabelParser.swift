import Foundation

/// Parses recognized text blocks into structured nutrition data.
/// Supports both English and Norwegian nutrition labels.
struct NutritionLabelParser {

    /// Result of parsing a nutrition label.
    struct ParsedNutrition: Sendable {
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var fiber: Double?
        var servingSize: String?
        var confidence: Double  // 0.0-1.0

        var isUsable: Bool {
            confidence >= 0.3 && (calories != nil || protein != nil)
        }

        var filledFieldCount: Int {
            [calories, protein, carbs, fat, fiber].compactMap { $0 }.count
        }
    }

    // MARK: - Bilingual Keywords

    private static let calorieKeywords = [
        // English
        "calories", "energy", "cal", "kcal",
        // Norwegian
        "energi", "kalorier"
    ]

    private static let proteinKeywords = [
        "protein", "proteiner"
    ]

    private static let carbKeywords = [
        // English
        "total carbohydrate", "carbohydrate", "carbohydrates", "carbs", "total carbs",
        // Norwegian
        "karbohydrater", "karbohydrat"
    ]

    private static let fatKeywords = [
        // English — "total fat" first so it matches before standalone "fat"
        "total fat",
        // Norwegian
        "totalt fett", "fett"
    ]

    /// Standalone "fat" is matched with word boundaries to avoid false positives
    private static let fatWordBoundaryKeyword = "fat"

    private static let fiberKeywords = [
        // English
        "dietary fiber", "fiber", "fibre",
        // Norwegian
        "fiber", "kostfiber"
    ]

    private static let servingSizeKeywords = [
        "serving size", "per serving", "per 100g", "per 100 g",
        "porsjonsstørrelse", "per porsjon", "per 100g", "per 100 g"
    ]

    // MARK: - Parsing

    /// Parse an array of recognized text blocks into nutrition data.
    func parse(textBlocks: [RecognizedTextBlock]) -> ParsedNutrition {
        // Join all lines for full-text analysis
        let allLines = textBlocks.map { cleanText($0.text) }
        let avgConfidence = textBlocks.isEmpty ? 0 : Double(textBlocks.reduce(0) { $0 + $1.confidence }) / Double(textBlocks.count)

        var result = ParsedNutrition(confidence: Double(avgConfidence))

        for line in allLines {
            let lower = line.lowercased()

            // Check each nutrient category
            if result.calories == nil, matchesAnyKeyword(lower, keywords: Self.calorieKeywords) {
                if let value = extractNumericValue(from: line) {
                    result.calories = convertToKcalIfNeeded(value: value, line: lower)
                }
            }

            if result.protein == nil, matchesAnyKeyword(lower, keywords: Self.proteinKeywords) {
                result.protein = extractNumericValue(from: line)
            }

            if result.carbs == nil, matchesAnyKeyword(lower, keywords: Self.carbKeywords) {
                result.carbs = extractNumericValue(from: line)
            }

            if result.fat == nil {
                let isFatLine: Bool
                if matchesAnyKeyword(lower, keywords: ["total fat", "totalt fett", "fett"]) {
                    // Exact multi-word match — skip lines with "saturated"/"trans" prefix
                    isFatLine = !lower.contains("saturated") && !lower.contains("trans") && !lower.contains("mettet")
                } else if lower.range(of: #"\bfat\b"#, options: .regularExpression) != nil {
                    // Word-boundary match for standalone "fat"
                    isFatLine = !lower.contains("saturated") && !lower.contains("trans") && !lower.contains("mettet")
                } else {
                    isFatLine = false
                }
                if isFatLine {
                    result.fat = extractNumericValue(from: line)
                }
            }

            if result.fiber == nil, matchesAnyKeyword(lower, keywords: Self.fiberKeywords) {
                result.fiber = extractNumericValue(from: line)
            }

            if result.servingSize == nil, matchesAnyKeyword(lower, keywords: Self.servingSizeKeywords) {
                result.servingSize = extractServingSize(from: line)
            }
        }

        // Calculate confidence based on fields found
        let fieldScore = Double(result.filledFieldCount) / 5.0
        result.confidence = min(1.0, (Double(avgConfidence) + fieldScore) / 2.0)

        return result
    }

    // MARK: - Text Cleaning

    /// Cleans OCR artifacts: O→0, l→1 in numeric contexts, normalize separators.
    func cleanText(_ text: String) -> String {
        var cleaned = text

        // Fix common OCR misreads in numeric context
        // Pattern: letter surrounded by digits or near "g" / "kcal"
        cleaned = cleaned.replacingOccurrences(of: "O,", with: "0,")
        cleaned = cleaned.replacingOccurrences(of: ",O", with: ",0")
        cleaned = cleaned.replacingOccurrences(of: "O.", with: "0.")
        cleaned = cleaned.replacingOccurrences(of: ".O", with: ".0")

        return cleaned
    }

    // MARK: - Value Extraction

    // Pre-compiled regex for numeric extraction
    private static let numericRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(\d+[.,]?\d*)\s*(?:g|mg|kcal|kj|kJ|cal)?"#, options: .caseInsensitive)
    }()

    /// Extracts the first numeric value from a string.
    /// Handles both `.` and `,` as decimal separators.
    func extractNumericValue(from text: String) -> Double? {
        guard let regex = Self.numericRegex else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        // Find rightmost number (usually the value, not a reference number)
        for match in matches.reversed() {
            guard let captureRange = Range(match.range(at: 1), in: text) else { continue }
            var numStr = String(text[captureRange])

            // Normalize comma decimal separator
            numStr = numStr.replacingOccurrences(of: ",", with: ".")

            if let value = Double(numStr), value >= 0, value < 10000 {
                return value
            }
        }

        return nil
    }

    /// Extracts serving size string from a line.
    private func extractServingSize(from text: String) -> String? {
        let pattern = #"(\d+[.,]?\d*)\s*(g|ml|oz)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    // MARK: - Helpers

    private func matchesAnyKeyword(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    /// Convert kJ to kcal if the line mentions kJ.
    private func convertToKcalIfNeeded(value: Double, line: String) -> Double {
        // Check for explicit kJ mention (case-insensitive, already lowercased)
        let hasKJ = line.range(of: #"\bkj\b"#, options: .regularExpression) != nil
        let hasKcal = line.contains("kcal")

        if hasKJ && !hasKcal {
            // Convert kJ to kcal: 1 kcal = 4.184 kJ
            return (value / 4.184).rounded()
        }
        return value
    }
}
