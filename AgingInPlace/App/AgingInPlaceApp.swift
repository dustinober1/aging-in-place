import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {

    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(
                for: Schema(AgingInPlaceSchemaV4.models),
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
                    for: Schema(AgingInPlaceSchemaV4.models),
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
