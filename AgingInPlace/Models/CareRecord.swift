import Foundation
import SwiftData

@Model
final class CareRecord {
    var id: UUID
    var category: PermissionCategory
    /// Stores AES-GCM sealed box bytes — NEVER plaintext
    var encryptedPayload: Data
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date
    var circle: CareCircle?

    init(category: PermissionCategory, encryptedPayload: Data, authorMemberID: UUID, circle: CareCircle? = nil) {
        self.id = UUID()
        self.category = category
        self.encryptedPayload = encryptedPayload
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
        self.circle = circle
    }
}
