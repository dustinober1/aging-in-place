import Foundation
import SwiftData

@Model
final class CareVisitLog {
    var id: UUID
    /// AES-GCM sealed JSON: { meals, mobility, observations, concerns }
    var encryptedPayload: Data
    /// Not encrypted — needed for predicate-based date filtering
    var visitDate: Date
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(
        encryptedPayload: Data,
        visitDate: Date,
        authorMemberID: UUID
    ) {
        self.id = UUID()
        self.encryptedPayload = encryptedPayload
        self.visitDate = visitDate
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
