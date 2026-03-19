import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {

    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            return try ModelContainer(
                for: Schema(AgingInPlaceSchemaV2.models),
                migrationPlan: AgingInPlaceMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
