import Foundation
import SwiftData

@Model
final class CalendarEvent {
    var id: UUID
    /// Event title stored unencrypted — used in notification content
    var title: String
    /// Not encrypted — needed for notification trigger calculation and predicate filtering
    var eventDate: Date
    /// Minutes before event to send reminder notification. Default: 60.
    var reminderOffsetMinutes: Int
    /// AES-GCM sealed JSON: { location, notes, attendees }
    var encryptedPayload: Data
    var createdByMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(
        title: String,
        eventDate: Date,
        reminderOffsetMinutes: Int = 60,
        encryptedPayload: Data,
        createdByMemberID: UUID
    ) {
        self.id = UUID()
        self.title = title
        self.eventDate = eventDate
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.encryptedPayload = encryptedPayload
        self.createdByMemberID = createdByMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
