import Foundation

enum PermissionCategory: String, Codable, CaseIterable {
    case medications
    case mood
    case careVisits
    case calendar

    var displayName: String {
        switch self {
        case .medications: return "Medications"
        case .mood: return "Mood"
        case .careVisits: return "Care Visits"
        case .calendar: return "Calendar"
        }
    }
}
