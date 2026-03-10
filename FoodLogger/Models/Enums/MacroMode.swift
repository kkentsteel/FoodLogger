import Foundation

enum MacroMode: String, Codable, Hashable, CaseIterable {
    case caloriesOnly
    case fullMacros

    var displayName: String {
        switch self {
        case .caloriesOnly: "Calories Only"
        case .fullMacros: "Full Macros"
        }
    }
}
