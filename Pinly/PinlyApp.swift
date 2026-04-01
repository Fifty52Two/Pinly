import SwiftUI
import SwiftData

@main
struct PinlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Place.self)
        }
    }
}
