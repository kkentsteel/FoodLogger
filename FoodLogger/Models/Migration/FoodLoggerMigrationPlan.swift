import SwiftData

enum FoodLoggerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FoodLoggerSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
