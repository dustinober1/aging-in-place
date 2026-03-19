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

    init(category: PermissionCategory, encryptedPayload: Data, authorMemberID: UUID) {
        self.id = UUID()
        self.category = category
        self.encryptedPayload = encryptedPayload
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
