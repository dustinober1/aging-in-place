import Foundation
import SwiftData

@Model
final class MedicationLog {
    var id: UUID = UUID()
    /// Optional link to MedicationSchedule.id if this was a scheduled dose
    var scheduleID: UUID?
    /// AES-GCM sealed JSON: { drugName, dose, notes }
    var encryptedPayload: Data = Data()
    /// Not encrypted — needed for predicate-based date sorting and filtering
    var administeredAt: Date = Date()
    var authorMemberID: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

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
