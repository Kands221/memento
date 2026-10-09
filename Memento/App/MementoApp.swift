import SwiftUI

@main
struct MementoApp: App {
    @State private var services = AppServices()
    @State private var app = AppModel()

    init() {
        if LaunchOptions.current.uiTesting { UIView.setAnimationsEnabled(false) }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-designGallery") {
                    DesignGallery()
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
            .environment(services)
            .environment(app)
            .modelContainer(services.container)
            .task { services.tagging.resumePending() }
        }
    }
}
