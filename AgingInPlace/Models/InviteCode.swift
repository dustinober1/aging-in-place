import Foundation
import SwiftData

@Model
final class InviteCode {
    var id: UUID
    var code: String
    var isUsed: Bool
    var createdAt: Date
    var circle: CareCircle?

    init(code: String, circle: CareCircle? = nil) {
        self.id = UUID()
        self.code = code
        self.isUsed = false
        self.createdAt = Date()
        self.circle = circle
    }
}
