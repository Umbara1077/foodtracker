import SwiftUI
import SwiftData

@main
struct ProjectPlateApp: App {
    private let environment: AppEnvironment
    private let container: ModelContainer

    init() {
        let container = PersistenceController.makeContainer()
        self.container = container
        self.environment = AppEnvironment.live(modelContainer: container)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, environment)
                .modelContainer(container)
        }
    }
}
