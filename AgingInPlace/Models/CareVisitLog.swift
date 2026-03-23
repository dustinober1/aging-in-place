import Foundation
import SwiftData

@Model
final class CareVisitLog {
    var id: UUID = UUID()
    /// AES-GCM sealed JSON: { meals, mobility, observations, concerns }
    var encryptedPayload: Data = Data()
    /// Not encrypted — needed for predicate-based date filtering
    var visitDate: Date = Date()
    var authorMemberID: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

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
