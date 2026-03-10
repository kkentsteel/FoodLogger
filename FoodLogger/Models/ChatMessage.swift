import SwiftData
import Foundation

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}
