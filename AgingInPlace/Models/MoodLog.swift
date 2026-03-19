import Foundation
import SwiftData

/// Author type for a mood log entry.
/// Stored as a String raw value so SwiftData can persist it without custom transformers.
enum MoodAuthorType: String, Codable, CaseIterable {
    case senior
    case caregiver
}

@Model
final class MoodLog {
    var id: UUID
    /// Integer 1–5 mood scale. Not encrypted — not PHI in isolation; needed for predicate queries.
    var moodValue: Int
    var authorMemberID: UUID
    /// Stored as String so SwiftData can persist the enum value
    var authorTypeRaw: String
    /// Optional encrypted payload for free-text notes (PHI)
    var notes: Data?
    var loggedAt: Date
    var lastModified: Date

    var authorType: MoodAuthorType {
        get { MoodAuthorType(rawValue: authorTypeRaw) ?? .senior }
        set { authorTypeRaw = newValue.rawValue }
    }

    init(
        moodValue: Int,
        authorMemberID: UUID,
        authorType: MoodAuthorType,
        notes: Data? = nil
    ) {
        self.id = UUID()
        self.moodValue = moodValue
        self.authorMemberID = authorMemberID
        self.authorTypeRaw = authorType.rawValue
        self.notes = notes
        self.loggedAt = Date()
        self.lastModified = Date()
    }
}
