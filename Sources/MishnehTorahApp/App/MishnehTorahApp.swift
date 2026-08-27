import SwiftData
import SwiftUI

@main
struct MishnehTorahApp: App {
    @StateObject private var appearance = AppearanceController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appearance)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
