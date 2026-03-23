import Foundation
import SwiftData

@Model
final class MedicationSchedule {
    var id: UUID = UUID()
    /// Drug name stored unencrypted — used in notification titles and predicate filtering
    var drugName: String = ""
    /// Dose stored unencrypted — used in notification body
    var dose: String = ""
    var scheduledHour: Int = 0
    var scheduledMinute: Int = 0
    /// Minutes after scheduled time before a missed-dose alert fires. Default: 30.
    var missedWindowMinutes: Int = 30
    var isActive: Bool = true
    var createdByMemberID: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

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
