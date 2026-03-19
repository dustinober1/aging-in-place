import Foundation
import SwiftData

@Model
final class MedicationLog {
    var id: UUID
    /// Optional link to MedicationSchedule.id if this was a scheduled dose
    var scheduleID: UUID?
    /// AES-GCM sealed JSON: { drugName, dose, notes }
    var encryptedPayload: Data
    /// Not encrypted — needed for predicate-based date sorting and filtering
    var administeredAt: Date
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(
        scheduleID: UUID? = nil,
        encryptedPayload: Data,
        administeredAt: Date,
        authorMemberID: UUID
    ) {
        self.id = UUID()
        self.scheduleID = scheduleID
        self.encryptedPayload = encryptedPayload
        self.administeredAt = administeredAt
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
