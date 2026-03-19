import Foundation
import SwiftData

@Model
final class CareTeamMember {
    var id: UUID
    var displayName: String
    var role: MemberRole
    var isProxy: Bool
    var grantedCategories: [PermissionCategory]
    var joinedAt: Date
    var lastModified: Date
    var circle: CareCircle?

    init(displayName: String, role: MemberRole, circle: CareCircle? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.role = role
        self.isProxy = false
        self.grantedCategories = PermissionCategory.allCases
        self.joinedAt = Date()
        self.lastModified = Date()
        self.circle = circle
    }
}
