import Foundation
import SwiftData

enum UserRole: String, Codable, CaseIterable {
    case senior
    case caregiver
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var iCloudRecordID: String = ""
    var displayName: String = ""
    var roleRaw: String = UserRole.senior.rawValue
    var avatarData: Data?
    var notificationsEnabled: Bool = true
    var createdAt: Date = Date()
    var lastModified: Date = Date()

    var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .senior }
        set { roleRaw = newValue.rawValue }
    }

    init(iCloudRecordID: String, displayName: String, role: UserRole) {
        self.id = UUID()
        self.iCloudRecordID = iCloudRecordID
        self.displayName = displayName
        self.roleRaw = role.rawValue
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
