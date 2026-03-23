import SwiftData

enum AgingInPlaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AgingInPlaceSchemaV1.self, AgingInPlaceSchemaV2.self, AgingInPlaceSchemaV3.self, AgingInPlaceSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
    }

    /// Lightweight migration: adding new entities requires no data transformation
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV1.self,
        toVersion: AgingInPlaceSchemaV2.self
    )

    /// Lightweight migration: adding optional circle relationship to CareRecord requires no data transformation
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV2.self,
        toVersion: AgingInPlaceSchemaV3.self
    )

    /// Lightweight migration: adding default values and iCloudRecordID to CareTeamMember for CloudKit compatibility
    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV3.self,
        toVersion: AgingInPlaceSchemaV4.self
    )
}
