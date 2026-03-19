import Foundation
import SwiftData

@Model
final class MedicationSchedule {
    var id: UUID
    /// Drug name stored unencrypted — used in notification titles and predicate filtering
    var drugName: String
    /// Dose stored unencrypted — used in notification body
    var dose: String
    var scheduledHour: Int
    var scheduledMinute: Int
    /// Minutes after scheduled time before a missed-dose alert fires. Default: 30.
    var missedWindowMinutes: Int
    var isActive: Bool
    var createdByMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(
        drugName: String,
        dose: String,
        hour: Int,
        minute: Int,
        missedWindowMinutes: Int = 30,
        createdByMemberID: UUID
    ) {
        self.id = UUID()
        self.drugName = drugName
        self.dose = dose
        self.scheduledHour = hour
        self.scheduledMinute = minute
        self.missedWindowMinutes = missedWindowMinutes
        self.isActive = true
        self.createdByMemberID = createdByMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
