import SwiftData

enum AgingInPlaceSchemaV2: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            // Phase 1 models (unchanged)
            CareCircle.self,
            CareTeamMember.self,
            CareRecord.self,
            InviteCode.self,
            EmergencyContact.self,
            // Phase 2 models (new)
            MedicationSchedule.self,
            MedicationLog.self,
            CareVisitLog.self,
            MoodLog.self,
            CalendarEvent.self
        ]
    }
}
