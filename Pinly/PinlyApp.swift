import SwiftUI
import SwiftData
import FirebaseCore

@main
struct PinlyApp: App {
    // Composition root: tüm concrete implementasyonlar ve stateful
    // manager'lar burada kurulur, protokol-tipli environment key'ler
    // veya @EnvironmentObject üzerinden alt view ağacına inject edilir.
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var placeStore = PlaceStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()

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
    private let starterRoutesProvider = DefaultStarterRoutesProvider()
    private let nearbySearchService = DefaultNearbySearchService.shared
    private let placePhotoStore = DefaultPlacePhotoStore.shared
    private let analyticsService = FirebaseAnalyticsService.shared

    init() {
        // Crashlytics + Analytics: rıza gerektirmez (ATT sonrası IDFA erişimi otomatik
        // düzelir), o yüzden ConsentManager/AdMob akışını beklemeden en erken noktada
        // başlatılır. AdMob SDK'sı ise burada BAŞLATILMIYOR — UMP rızası + ATT izni
        // alınmadan reklam isteği atılamaz (bkz. ConsentManager); gerçek başlatma
        // ContentView'in ilk onAppear'ında, rıza akışı tamamlanınca yapılır.
        FirebaseApp.configure()
        DiagnosticsCollector.shared.register()
        // İzin İSTEMEZ — yalnızca izin zaten verilmişse haftalık bildirimi yeniden planlar.
        // İzin isteme anı Haftalık Rapor ekranındaki CTA'da (FAZ 5.4).
        notificationScheduler.scheduleWeeklyNotification()
        DefaultBadgeService.shared.recordAppOpen()
        notificationScheduler.scheduleStreakReminder(
            consecutiveDays: DefaultBadgeService.shared.consecutiveDays
        )
        // Emekli edilen çoklu tema tercihinin temizliği (tek slate temaya geçildi)
        UserDefaults.standard.removeObject(forKey: "pinly.theme")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Place.self, RouteHistory.self, SavedRoute.self])
                .environmentObject(languageManager)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
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
                .environment(\.starterRoutes, starterRoutesProvider)
                .environment(\.nearbySearch, nearbySearchService)
                .environment(\.placePhotos, placePhotoStore)
                .environment(\.analytics, analyticsService)
        }
    }
}
