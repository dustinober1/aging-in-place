import Foundation
import SwiftData

@Model
final class EmergencyContact {
    var id: UUID
    var name: String
    var phone: String
    var relationship: String
    /// Stored as plaintext — not PHI-gated, always visible per user decision
    var medicalNotes: String?
    var lastModified: Date

    init(name: String, phone: String, relationship: String, medicalNotes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.relationship = relationship
        self.medicalNotes = medicalNotes
        self.lastModified = Date()
    }
}
