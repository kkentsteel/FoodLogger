import Foundation

enum FoodSource: String, Codable, Hashable {
    case manual
    case barcode
    case ocr
    case openFoodFacts
    case seed
    case matvaretabellen
    case quickAdd
    case aiParsed
}
