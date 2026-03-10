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

    // External identifiers
    var matvaretabellenId: String?
    var foodGroupId: String?

    // Metadata
    var source: FoodSource
    var isFavorite: Bool
    var usageCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \LogEntry.foodItem)
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
