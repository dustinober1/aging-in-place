import Foundation
import SwiftData

@Model
final class CareRecord {
    var id: UUID = UUID()
    var category: PermissionCategory = PermissionCategory.medications
    /// Stores AES-GCM sealed box bytes — NEVER plaintext
    var encryptedPayload: Data = Data()
    var authorMemberID: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()
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
