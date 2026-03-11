import SwiftData
import Foundation

@Model
final class FoodItem {
    // Identity
    var name: String
    var brand: String?
    var barcode: String?

    // Nutrition per serving
    var servingSize: Double
    var servingUnit: ServingUnit
    var servingLabel: String?

    // Macros per serving
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    var fiberPerServing: Double?

    // Micronutrients per serving
    var saturatedFatPerServing: Double?
    var monounsaturatedFatPerServing: Double?
    var polyunsaturatedFatPerServing: Double?
    var transFatPerServing: Double?
    var omega3PerServing: Double?
    var omega6PerServing: Double?
    var cholesterolPerServing: Double?    // mg
    var sugarPerServing: Double?
    var addedSugarPerServing: Double?
    var starchPerServing: Double?
    var saltPerServing: Double?           // g (NaCl)
    var waterPerServing: Double?

    // Vitamins per serving
    var vitaminAPerServing: Double?       // RAE (µg)
    var vitaminDPerServing: Double?       // µg
    var vitaminEPerServing: Double?       // mg-ATE
    var vitaminCPerServing: Double?       // mg
    var vitaminB1PerServing: Double?      // mg (thiamin)
    var vitaminB2PerServing: Double?      // mg (riboflavin)
    var vitaminB6PerServing: Double?      // mg
    var vitaminB12PerServing: Double?     // µg
    var niacinPerServing: Double?         // mg
    var folatePerServing: Double?         // µg

    // Minerals per serving
    var calciumPerServing: Double?        // mg
    var ironPerServing: Double?           // mg
    var magnesiumPerServing: Double?      // mg
    var potassiumPerServing: Double?      // mg
    var sodiumPerServing: Double?         // mg
    var zincPerServing: Double?           // mg
    var seleniumPerServing: Double?       // µg
    var phosphorusPerServing: Double?     // mg
    var copperPerServing: Double?         // mg
    var iodinePerServing: Double?         // µg

    // External identifiers
    var matvaretabellenId: String?
    var foodGroupId: String?
    var foodGroupName: String?

    // Edible part percentage (from Matvaretabellen)
    var ediblePartPercent: Int?

    // Metadata
    var source: FoodSource
    var isFavorite: Bool
    var usageCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \LogEntry.foodItem)
    var logEntries: [LogEntry]

    // Computed: macros per gram
    var caloriesPerGram: Double {
        guard servingSize > 0 else { return 0 }
        return caloriesPerServing / servingSize
    }

    var proteinPerGram: Double {
        guard servingSize > 0 else { return 0 }
        return proteinPerServing / servingSize
    }

    var carbsPerGram: Double {
        guard servingSize > 0 else { return 0 }
        return carbsPerServing / servingSize
    }

    var fatPerGram: Double {
        guard servingSize > 0 else { return 0 }
        return fatPerServing / servingSize
    }

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        servingSize: Double = 100,
        servingUnit: ServingUnit = .grams,
        servingLabel: String? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double = 0,
        carbsPerServing: Double = 0,
        fatPerServing: Double = 0,
        fiberPerServing: Double? = nil,
        source: FoodSource = .manual
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.servingLabel = servingLabel
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbsPerServing = carbsPerServing
        self.fatPerServing = fatPerServing
        self.fiberPerServing = fiberPerServing
        self.source = source
        self.isFavorite = false
        self.usageCount = 0
        self.lastUsedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.logEntries = []
    }
}
