import Foundation

enum ActivityLevel: String, Codable, Hashable, CaseIterable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary (little/no exercise)"
        case .lightlyActive: "Lightly Active (1-3 days/week)"
        case .moderatelyActive: "Moderately Active (3-5 days/week)"
        case .veryActive: "Very Active (6-7 days/week)"
        case .extraActive: "Extra Active (athlete/physical job)"
        }
    }
}
