import SwiftUI
#if !LEGACY_BUILD
import SwiftData
#endif

@main
struct ProjectPlateApp: App {
    private let environment: AppEnvironment
#if !LEGACY_BUILD
    private let container: ModelContainer
#endif

    init() {
#if LEGACY_BUILD
        self.environment = AppEnvironment.live()
#else
        let container = PersistenceController.makeContainer()
        self.container = container
        self.environment = AppEnvironment.live(modelContainer: container)
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, environment)
#if !LEGACY_BUILD
                .modelContainer(container)
#endif
        }
    }
}
