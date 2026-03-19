import Foundation
import SwiftData

@Model
final class CareCircle {
    var id: UUID
    var seniorName: String
    var seniorDeviceID: String
    @Relationship(deleteRule: .cascade, inverse: \CareTeamMember.circle)
    var members: [CareTeamMember]
    @Relationship(deleteRule: .cascade, inverse: \InviteCode.circle)
    var pendingInvites: [InviteCode]
    var lastModified: Date

    init(seniorName: String, seniorDeviceID: String = "") {
        self.id = UUID()
        self.seniorName = seniorName
        self.seniorDeviceID = seniorDeviceID
        self.members = []
        self.pendingInvites = []
        self.lastModified = Date()
    }
}
