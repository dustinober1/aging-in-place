import SwiftData

enum AgingInPlaceSchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CareCircle.self,
            CareTeamMember.self,
            CareRecord.self,
            InviteCode.self,
            EmergencyContact.self
        ]
    }
}
