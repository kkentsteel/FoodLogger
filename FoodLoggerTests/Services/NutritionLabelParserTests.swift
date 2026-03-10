import Testing
import Foundation
@testable import FoodLogger

@Suite("NutritionLabelParser Tests")
struct NutritionLabelParserTests {

    let parser = NutritionLabelParser()

    // MARK: - Numeric Extraction

    @Test("Extract number from simple text")
    func extractSimple() {
        #expect(parser.extractNumericValue(from: "Calories 250") == 250)
        #expect(parser.extractNumericValue(from: "Protein 12g") == 12)
        #expect(parser.extractNumericValue(from: "Fat 8.5g") == 8.5)
    }

    @Test("Extract number with comma decimal separator")
    func extractCommaDecimal() {
        #expect(parser.extractNumericValue(from: "Protein 12,5g") == 12.5)
        #expect(parser.extractNumericValue(from: "Fett 3,2 g") == 3.2)
    }

    @Test("Extract rightmost number from line with multiple numbers")
    func extractRightmost() {
        // "per 100g" lines: the rightmost number is the value
        let value = parser.extractNumericValue(from: "Protein per 100g 8.5g")
        #expect(value == 8.5)
    }

    @Test("Extract number returns nil for text-only input")
    func extractNoNumber() {
        #expect(parser.extractNumericValue(from: "No numbers here") == nil)
        #expect(parser.extractNumericValue(from: "") == nil)
    }

    @Test("Extract rejects values over 10000")
    func extractRejectsHugeValues() {
        // 10000+ should be nil (sanity check)
        #expect(parser.extractNumericValue(from: "Energy 15000kcal") == nil)
    }

    @Test("Extract handles zero values")
    func extractZero() {
        #expect(parser.extractNumericValue(from: "Fiber 0g") == 0)
        #expect(parser.extractNumericValue(from: "Protein 0.0g") == 0)
    }

    // MARK: - English Label Parsing

    @Test("Parse English nutrition label")
    func parseEnglishLabel() {
        let blocks = makeBlocks([
            "Nutrition Facts",
            "Serving Size 40g",
            "Calories 210",
            "Total Fat 8g",
            "Total Carbohydrate 29g",
            "Protein 4g",
            "Dietary Fiber 2g"
        ])

        let result = parser.parse(textBlocks: blocks)

        #expect(result.calories == 210)
        #expect(result.protein == 4)
        #expect(result.carbs == 29)
        #expect(result.fat == 8)
        #expect(result.fiber == 2)
    }

    @Test("Parse English label with 'Total Carbs' variant")
    func parseEnglishTotalCarbs() {
        let blocks = makeBlocks([
            "Calories 180",
            "Total Carbs 22g",
            "Protein 6g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.carbs == 22)
    }

    @Test("Parse English label with 'Fibre' spelling")
    func parseEnglishFibreSpelling() {
        let blocks = makeBlocks([
            "Calories 120",
            "Dietary Fibre 4g",
            "Protein 3g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fiber == 4)
    }

    // MARK: - Norwegian Label Parsing

    @Test("Parse Norwegian nutrition label")
    func parseNorwegianLabel() {
        let blocks = makeBlocks([
            "Næringsinnhold per 100g",
            "Energi 1450 kJ",
            "Fett 12,5g",
            "Karbohydrater 52g",
            "Protein 8,3g",
            "Fiber 3,1g"
        ])

        let result = parser.parse(textBlocks: blocks)

        #expect(result.calories != nil)
        #expect(result.fat == 12.5)
        #expect(result.carbs == 52)
        #expect(result.protein == 8.3)
        #expect(result.fiber == 3.1)
    }

    @Test("Parse Norwegian label with 'Kostfiber'")
    func parseNorwegianKostfiber() {
        let blocks = makeBlocks([
            "Energi 800 kJ",
            "Kostfiber 5,2g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fiber == 5.2)
    }

    @Test("Parse Norwegian label with 'Karbohydrat' singular")
    func parseNorwegianSingular() {
        let blocks = makeBlocks([
            "Karbohydrat 45g",
            "Protein 12g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.carbs == 45)
    }

    @Test("Parse Norwegian label with 'Totalt fett'")
    func parseNorwegianTotaltFett() {
        let blocks = makeBlocks([
            "Totalt fett 9,8g",
            "Protein 7g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fat == 9.8)
    }

    // MARK: - kJ to kcal Conversion

    @Test("kJ values are converted to kcal")
    func kjConversion() {
        let blocks = makeBlocks([
            "Energi 1450 kJ",
            "Protein 10g"
        ])

        let result = parser.parse(textBlocks: blocks)
        // 1450 kJ / 4.184 ≈ 347 kcal
        #expect(result.calories != nil)
        if let cal = result.calories {
            #expect(cal > 340 && cal < 355)
        }
    }

    @Test("Small kJ values not converted (could be kcal already)")
    func smallKjNotConverted() {
        let blocks = makeBlocks([
            "Energy 250 kJ"
        ])

        let result = parser.parse(textBlocks: blocks)
        // Value <= 500, so treated as kcal already
        #expect(result.calories == 250)
    }

    @Test("kcal values not converted")
    func kcalNotConverted() {
        let blocks = makeBlocks([
            "Calories 800 kcal"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.calories == 800)
    }

    // MARK: - Text Cleaning

    @Test("Clean OCR misreads O→0")
    func cleanOCRMisreads() {
        let cleaned = parser.cleanText("Protein O,5g")
        #expect(cleaned.contains("0,5"))
    }

    @Test("Clean OCR misread O. to 0.")
    func cleanOCRDotMisread() {
        let cleaned = parser.cleanText("Fat O.5g")
        #expect(cleaned.contains("0.5"))
    }

    @Test("Clean OCR preserves normal text")
    func cleanPreservesNormal() {
        let text = "Protein 12.5g"
        let cleaned = parser.cleanText(text)
        #expect(cleaned == text)
    }

    // MARK: - Confidence Scoring

    @Test("Full label has high confidence")
    func fullLabelConfidence() {
        let blocks = makeBlocks([
            "Calories 200",
            "Protein 10g",
            "Total Carbohydrate 25g",
            "Total Fat 8g",
            "Fiber 3g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.filledFieldCount == 5)
        #expect(result.confidence >= 0.5)
        #expect(result.isUsable)
    }

    @Test("Empty text has zero confidence")
    func emptyTextConfidence() {
        let result = parser.parse(textBlocks: [])
        #expect(result.confidence == 0)
        #expect(result.filledFieldCount == 0)
        #expect(!result.isUsable)
    }

    @Test("Partial label is still usable")
    func partialLabelUsable() {
        let blocks = makeBlocks([
            "Calories 150",
            "Protein 5g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.calories == 150)
        #expect(result.protein == 5)
        #expect(result.isUsable)
    }

    @Test("Low confidence blocks reduce overall confidence")
    func lowConfidenceBlocks() {
        let blocks = [
            RecognizedTextBlock(text: "Calories 200", confidence: 0.2, boundingBox: .zero),
            RecognizedTextBlock(text: "Protein 10g", confidence: 0.2, boundingBox: .zero)
        ]

        let result = parser.parse(textBlocks: blocks)
        #expect(result.calories == 200)
        // With 0.2 avg confidence and 2/5 fields, confidence should be relatively low
        #expect(result.confidence < 0.5)
        // But still usable since we have calories
        #expect(result.isUsable)
    }

    @Test("Only protein detected is usable")
    func onlyProteinUsable() {
        let blocks = makeBlocks(["Protein 25g"])
        let result = parser.parse(textBlocks: blocks)
        #expect(result.protein == 25)
        #expect(result.calories == nil)
        #expect(result.isUsable) // protein alone makes it usable
    }

    @Test("Unrelated text is not usable")
    func unrelatedTextNotUsable() {
        let blocks = makeBlocks([
            "Ingredients: wheat flour, sugar, eggs",
            "Store in a cool dry place",
            "Best before: 2026/12/31"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.filledFieldCount == 0)
        #expect(!result.isUsable)
    }

    // MARK: - Edge Cases

    @Test("Saturated fat line is not matched as fat")
    func saturatedFatNotMatched() {
        let blocks = makeBlocks([
            "Saturated Fat 3g",
            "Total Fat 8g",
            "Protein 5g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fat == 8) // Should match "Total Fat", not "Saturated Fat"
    }

    @Test("Trans fat line is not matched as fat")
    func transFatNotMatched() {
        let blocks = makeBlocks([
            "Trans Fat 0g",
            "Total Fat 12g",
            "Protein 8g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fat == 12)
    }

    @Test("Norwegian mettet fett not matched as fat")
    func norwegianMettetFettNotMatched() {
        let blocks = makeBlocks([
            "Mettet fett 3g",
            "Fett 15g",
            "Protein 10g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.fat == 15)
    }

    @Test("Serving size extraction")
    func servingSizeExtraction() {
        let blocks = makeBlocks([
            "Serving Size 30g",
            "Calories 120"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.servingSize == "30g")
    }

    @Test("Serving size extraction with ml")
    func servingSizeExtractionMl() {
        let blocks = makeBlocks([
            "Per Serving 250ml",
            "Calories 90"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.servingSize == "250ml")
    }

    @Test("First matching value wins for each field")
    func firstValueWins() {
        let blocks = makeBlocks([
            "Calories 200",
            "Energy 300 kcal"  // "Energy" is also a calorie keyword
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.calories == 200) // First match should win
    }

    @Test("Mixed English and Norwegian lines")
    func mixedLanguageLabel() {
        let blocks = makeBlocks([
            "Calories 250",
            "Fett 10g",
            "Karbohydrater 30g",
            "Protein 8g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.calories == 250)
        #expect(result.fat == 10)
        #expect(result.carbs == 30)
        #expect(result.protein == 8)
    }

    @Test("FilledFieldCount accuracy")
    func filledFieldCount() {
        let blocks = makeBlocks([
            "Calories 200",
            "Protein 10g",
            "Fat 5g"
        ])

        let result = parser.parse(textBlocks: blocks)
        #expect(result.filledFieldCount == 3)
    }

    // MARK: - ParsedNutrition Properties

    @Test("ParsedNutrition isUsable boundary at confidence 0.3")
    func isUsableBoundary() {
        var nutrition = NutritionLabelParser.ParsedNutrition(confidence: 0.3)
        nutrition.calories = 100
        #expect(nutrition.isUsable)

        var lowConf = NutritionLabelParser.ParsedNutrition(confidence: 0.29)
        lowConf.calories = 100
        #expect(!lowConf.isUsable)
    }

    @Test("ParsedNutrition requires calories or protein for usable")
    func isUsableRequiresCalOrProtein() {
        var nutrition = NutritionLabelParser.ParsedNutrition(confidence: 0.8)
        nutrition.carbs = 30
        nutrition.fat = 10
        // Has high confidence but no calories or protein
        #expect(!nutrition.isUsable)
    }

    // MARK: - Helper

    private func makeBlocks(_ lines: [String]) -> [RecognizedTextBlock] {
        lines.enumerated().map { index, text in
            RecognizedTextBlock(
                text: text,
                confidence: 0.9,
                boundingBox: CGRect(x: 0, y: Double(index) * 0.1, width: 1, height: 0.1)
            )
        }
    }
}
