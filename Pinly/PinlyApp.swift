import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct PinlyApp: App {
    @StateObject private var languageManager = LanguageManager()

    // Composition root: gerçek servis implementasyonları burada kurulur
    // ve environment üzerinden inject edilir.
    private let entitlementService = LocalEntitlementService.shared
    private let badgeService = DefaultBadgeService.shared
    private let adService = AdManager.shared

    init() {
        MobileAds.shared.start { _ in }
        // Bildirim izni ilk açılışta onboarding'in üstüne düşmesin —
        // yeni kullanıcıda onboarding bitince (ContentView) tetiklenir
        if UserDefaults.standard.bool(forKey: "pinly.hasSeenOnboarding") {
            WeeklyReportManager.scheduleWeeklyNotification()
        }
        DefaultBadgeService.shared.recordAppOpen()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Place.self, RouteHistory.self, SavedRoute.self])
                .environmentObject(languageManager)
                .environment(\.entitlements, entitlementService)
                .environment(\.badges, badgeService)
                .environment(\.ads, adService)
        }
    }
}
