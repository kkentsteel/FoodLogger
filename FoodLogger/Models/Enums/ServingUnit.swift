import Foundation

enum ServingUnit: String, Codable, Hashable, CaseIterable {
    case grams = "g"
    case milliliters = "ml"
    case pieces = "pcs"
    case cups = "cup"
    case tablespoons = "tbsp"
    case teaspoons = "tsp"
    case ounces = "oz"
    case slices = "slice"
    case portions = "portion"

    var displayName: String {
        switch self {
        case .grams: "Grams (g)"
        case .milliliters: "Milliliters (ml)"
        case .pieces: "Pieces (pcs)"
        case .cups: "Cups"
        case .tablespoons: "Tablespoons (tbsp)"
        case .teaspoons: "Teaspoons (tsp)"
        case .ounces: "Ounces (oz)"
        case .slices: "Slices"
        case .portions: "Portions"
        }
    }
}
