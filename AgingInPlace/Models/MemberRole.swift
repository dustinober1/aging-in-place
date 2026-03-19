import Foundation

enum MemberRole: String, Codable, CaseIterable {
    case family
    case paidAide
    case nurse
    case doctor
    case other

    var displayName: String {
        switch self {
        case .family: return "Family"
        case .paidAide: return "Paid Aide"
        case .nurse: return "Nurse"
        case .doctor: return "Doctor"
        case .other: return "Other"
        }
    }
}
