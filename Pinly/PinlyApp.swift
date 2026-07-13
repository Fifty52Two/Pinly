import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct PinlyApp: App {
    // Composition root: tüm concrete implementasyonlar ve stateful
    // manager'lar burada kurulur, protokol-tipli environment key'ler
    // veya @EnvironmentObject üzerinden alt view ağacına inject edilir.
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var placeStore = PlaceStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()
    @StateObject private var themeManager = ThemeManager.shared

    private let entitlementService = LocalEntitlementService.shared
    private let badgeService = DefaultBadgeService.shared
    private let adService = AdManager.shared
    private let geocodingService = DefaultGeocodingService.shared
    private let healthStatsService = HealthKitService.shared
    private let savedRouteRepository = DefaultSavedRouteRepository.shared
    private let routeURLCoder = DefaultRouteURLCoder()
    private let swarmImporter = DefaultSwarmImporter()
    private let routeExporter = DefaultRouteExporter()
    private let weeklyStatsComputer = DefaultWeeklyStatsComputer()
    private let notificationScheduler = DefaultNotificationScheduler()
    private let qrCodeGenerator = DefaultQRCodeGenerator()
    private let profileService = DefaultProfileService.shared

    init() {
        MobileAds.shared.start { _ in }
        // Bildirim izni ilk açılışta onboarding'in üstüne düşmesin —
        // yeni kullanıcıda onboarding bitince (ContentView) tetiklenir
        if UserDefaults.standard.bool(forKey: "pinly.hasSeenOnboarding") {
            notificationScheduler.scheduleWeeklyNotification()
        }
        DefaultBadgeService.shared.recordAppOpen()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Place.self, RouteHistory.self, SavedRoute.self])
                .environmentObject(languageManager)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
                .environmentObject(themeManager)
                .environment(\.entitlements, entitlementService)
                .environment(\.badges, badgeService)
                .environment(\.ads, adService)
                .environment(\.geocoding, geocodingService)
                .environment(\.healthStats, healthStatsService)
                .environment(\.savedRoutes, savedRouteRepository)
                .environment(\.routeURLCoding, routeURLCoder)
                .environment(\.swarmImporting, swarmImporter)
                .environment(\.routeExporting, routeExporter)
                .environment(\.weeklyStats, weeklyStatsComputer)
                .environment(\.notificationScheduling, notificationScheduler)
                .environment(\.qrCodeGenerator, qrCodeGenerator)
                .environment(\.profile, profileService)
        }
    }
}
