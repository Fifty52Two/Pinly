import SwiftUI
import SwiftData

@main
struct NotionGOApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Place.self)
        }
    }
}