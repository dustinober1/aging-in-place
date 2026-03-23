import SwiftData

enum AgingInPlaceSchemaV3: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            // Phase 1 models
            CareCircle.self,
            CareTeamMember.self,
            CareRecord.self,
            InviteCode.self,
            EmergencyContact.self,
            // Phase 2 models
            MedicationSchedule.self,
            MedicationLog.self,
            CareVisitLog.self,
            MoodLog.self,
            CalendarEvent.self
        ]
    }
}
