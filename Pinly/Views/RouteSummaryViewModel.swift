import Foundation
import SwiftData

// MARK: - RouteSummaryViewModel
//
// RouteSummaryView'ın iş mantığı (not ekleme, varış/tamamlanma orkestrasyonu,
// dışa aktarma, rota kaydetme, rozet kaydı) buradan yönetilir. `PlacesListViewModel`
// deseninin devamı: stateful, oturuma özel bağımlılıklar (RouteManager, PlaceStore,
// LocationManager, ModelContext) constructor'da tutulmaz — SwiftUI'da @StateObject
// View init'inde kurulduğu için environment henüz hazır değildir; bunun yerine
// bu bağımlılıklar ilgili metodlara parametre olarak geçirilir. Sadece varsayılan
// singleton'ları olan servisler (badges/entitlements/ads/healthStats/savedRoutes/
// routeExporter) constructor injection ile alınır.

@MainActor
final class RouteSummaryViewModel: ObservableObject {
    @Published var isLoadingRoutes = false
    @Published var arrivedPlaceName = ""
    @Published var pendingRatingPlace: Place? = nil
    @Published var stopNote = ""
    @Published var shareRouteName = ""
    @Published var shareRouteCategory: RouteCategory = .city
    @Published var saveRouteName = ""
    @Published var saveRouteSuccess = false
    @Published var routeStartDate: Date? = nil

    private let badges: BadgeServicing
    private let entitlements: EntitlementProviding
    private let ads: AdPresenting
    private let healthStats: HealthStatsProviding
    private let savedRoutes: SavedRouteRepository
    private let routeExporter: RouteExporting

    init(
        badges: BadgeServicing = DefaultBadgeService.shared,
        entitlements: EntitlementProviding = LocalEntitlementService.shared,
        ads: AdPresenting = AdManager.shared,
        healthStats: HealthStatsProviding = HealthKitService.shared,
        savedRoutes: SavedRouteRepository = DefaultSavedRouteRepository.shared,
        routeExporter: RouteExporting = DefaultRouteExporter()
    ) {
        self.badges = badges
        self.entitlements = entitlements
        self.ads = ads
        self.healthStats = healthStats
        self.savedRoutes = savedRoutes
        self.routeExporter = routeExporter
    }

    var isPro: Bool { entitlements.isPro }

    func exportRouteName(fallbackRouteName: String) -> String {
        if !shareRouteName.isEmpty { return shareRouteName }
        if !fallbackRouteName.isEmpty { return fallbackRouteName }
        return NSLocalizedString("Rota", comment: "")
    }

    // MARK: - Not Ekleme

    @discardableResult
    func addNoteToCurrentStop(routePlaces: [Place], currentWaypointIndex: Int, context: ModelContext, placeStore: PlaceRepository) -> Bool {
        let trimmed = stopNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, currentWaypointIndex < routePlaces.count else { return false }

        let place = routePlaces[currentWaypointIndex]
        if place.notes.isEmpty {
            place.notes = trimmed
        } else {
            place.notes += "\n• \(trimmed)"
        }
        try? context.save()
        placeStore.load(context: context)
        stopNote = ""
        return true
    }

    // MARK: - Varış / Tamamlanma

    func handleArrival(place: Place, context: ModelContext, placeStore: PlaceRepository) {
        place.isVisited = true
        place.visitCount += 1
        try? context.save()
        placeStore.load(context: context)
        arrivedPlaceName = place.name
        pendingRatingPlace = place
    }

    func recordRouteStarted() {
        badges.recordRouteStarted()
    }

    /// Sağlık izni reddedildiyse true — adım/mesafe istatistiklerinin neden boş
    /// kalacağını kullanıcıya açıklamak için (eskiden sonuç sessizce atılıyordu).
    @Published var healthKitDenied = false

    func requestHealthKitAuthorization() async {
        healthKitDenied = !(await healthStats.requestAuthorization())
    }

    /// Rota tamamlanınca HealthKit istatistiklerini çeker, RouteHistory kaydeder,
    /// rozet ilerlemesini işler. Yeni açılan rozetleri döndürür.
    func handleRouteCompletion(
        routePlaces: [Place],
        fallbackRouteName: String,
        totalDistance: Double,
        totalTime: TimeInterval,
        context: ModelContext,
        placeStore: PlaceRepository
    ) async -> [Badge] {
        badges.recordRouteCompleted()
        let newBadges = badges.check(placeStore: placeStore)

        let startDate = routeStartDate ?? Date()
        let endDate = Date()
        let name = exportRouteName(fallbackRouteName: fallbackRouteName)
        let placeNames = routePlaces.map(\.name)
        let catRaw = shareRouteCategory.rawValue

        let stats = await healthStats.fetchRouteStats(from: startDate, to: endDate)
        let history = RouteHistory(
            routeName: name,
            placeNames: placeNames,
            totalDistanceMeters: totalDistance,
            durationSeconds: totalTime,
            stepCount: stats.steps,
            categoryRaw: catRaw
        )
        context.insert(history)
        try? context.save()

        return newBadges
    }

    // MARK: - Paylaşım / Dışa Aktarma

    func sharePDF(places: [Place], fallbackRouteName: String, totalDistance: Double) -> URL? {
        let distanceStr = totalDistance > 0 ? String(format: "%.1f km", totalDistance / 1000) : ""
        return routeExporter.buildPDFFile(
            for: places,
            name: exportRouteName(fallbackRouteName: fallbackRouteName),
            totalDistance: distanceStr,
            totalTime: ""
        )
    }

    func shareGPX(places: [Place], fallbackRouteName: String) -> URL? {
        routeExporter.buildGPXFile(for: places, name: exportRouteName(fallbackRouteName: fallbackRouteName))
    }

    func recordRouteShared(placeStore: PlaceRepository) -> [Badge] {
        badges.recordRouteShared()
        return badges.check(placeStore: placeStore)
    }

    func showInterstitialThenProceed(then completion: @escaping () -> Void) {
        ads.showInterstitialIfNeeded(then: completion)
    }

    // MARK: - Rota Kaydetme

    func saveRoute(name: String, category: RouteCategory, places: [Place], context: ModelContext, placeStore: PlaceRepository) -> [Badge] {
        savedRoutes.save(name: name, categoryRaw: category.rawValue, places: places, context: context)
        badges.recordSavedRoute()
        return badges.check(placeStore: placeStore)
    }
}
