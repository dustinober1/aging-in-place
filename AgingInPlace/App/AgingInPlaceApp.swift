import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {

    let container: ModelContainer = {
        do {
            // cloudKitDatabase: .automatic requires all model attributes to be optional
            // or have defaults. Kept as .none until models are made CloudKit-compatible.
            // Change to .automatic when model attributes are updated.
            let config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: Schema(AgingInPlaceSchemaV3.models),
                migrationPlan: AgingInPlaceMigrationPlan.self,
                configurations: config
            )
        } catch {
            do {
                let fallback = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(
                    for: Schema(AgingInPlaceSchemaV3.models),
                    configurations: fallback
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()

    @State private var syncMonitor = CloudKitSyncMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncMonitor)
                .onAppear {
                    syncMonitor.startMonitoring()
                }
        }
        .modelContainer(container)
    }
}
