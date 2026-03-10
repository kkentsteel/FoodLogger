import Foundation

extension Double {
    var formattedCalories: String {
        "\(Int(rounded())) kcal"
    }

    var formattedGrams: String {
        if self == rounded() {
            return "\(Int(self))g"
        }
        return String(format: "%.1fg", self)
    }

    var formattedOneDecimal: String {
        if self == rounded() {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}
