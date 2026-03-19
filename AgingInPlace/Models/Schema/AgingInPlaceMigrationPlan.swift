import SwiftData

enum AgingInPlaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AgingInPlaceSchemaV1.self, AgingInPlaceSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Lightweight migration: adding new entities requires no data transformation
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV1.self,
        toVersion: AgingInPlaceSchemaV2.self
    )
}
