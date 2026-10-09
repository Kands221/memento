import SwiftUI

@main
struct MementoApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-designGallery") {
                DesignGallery()
            } else {
                Text("Memento")
            }
            #else
            Text("Memento")
            #endif
        }
    }
}
