import Foundation

enum BiologicalSex: String, Codable, Hashable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}
