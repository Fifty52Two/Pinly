import Foundation
import SwiftData
import UIKit

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

    /// Anı Günlüğü (FAZ 3): stopIndex → o durakta çekilen anı fotoğraflarının
    /// dosya adları (en fazla 3). `RouteManager`'a hiç girmez — bu view model
    /// oturuma özel taşır, `completeRoute` anında `RouteHistory`'ye yazılır.
    @Published var stopPhotos: [Int: [String]] = [:]
    /// Durakta puanlama sheet'i açıkken hangi durağın fotoğraflandığını bilmek
    /// için — `RouteManager.currentWaypointIndex` son duraktaki varışta rotanın
    /// SONUNU gösterdiği için (bkz. `handleWaypointArrival`), arrival anında
    /// `place`'in `routePlaces` içindeki index'i buraya ayrıca kaydedilir.
    @Published var pendingRatingStopIndex: Int = 0

    /// Rota tamamlanınca HealthKit'ten çekilen adım sayısı — `RouteCompletionOverlay`
    /// Wow #1 sekansındaki üçüncü istatistik satırı (km → dk → adım) için.
    /// `handleRouteCompletion` async olduğundan overlay ilk göründüğünde 0 olabilir,
    /// sonra @Published güncellemesiyle satır kendini tazeler (bkz. RouteSummaryView).
    @Published var lastCompletionStepCount: Int = 0

    /// Bu rotanın tamamlanınca yazılacağı `RouteHistory.id` — anı fotoğrafları
    /// tamamlanmadan ÖNCE bu ID altına kaydedilir (rota bitmeden app ölürse
    /// fotoğraf kaybolmasın); `handleRouteCompletion` aynı ID'yle kaydı yaratır,
    /// böylece disk klasörü ile SwiftData kaydı hep eşleşir.
    let pendingHistoryID = UUID()

    private let badges: BadgeServicing
    private let entitlements: EntitlementProviding
    private let ads: AdPresenting
    private let healthStats: HealthStatsProviding
    private let savedRoutes: SavedRouteRepository
    private let routeExporter: RouteExporting
    private let analytics: AnalyticsTracking
    private let routeMemories: RouteMemoryStoring
    private let memoryCards: MemoryCardComposing
    private let placePhotos: PlacePhotoStoring

    init(
        badges: BadgeServicing = DefaultBadgeService.shared,
        entitlements: EntitlementProviding = LocalEntitlementService.shared,
        ads: AdPresenting = AdManager.shared,
        healthStats: HealthStatsProviding = HealthKitService.shared,
        savedRoutes: SavedRouteRepository = DefaultSavedRouteRepository.shared,
        routeExporter: RouteExporting = DefaultRouteExporter(),
        analytics: AnalyticsTracking = RuntimeAnalyticsService.shared,
        routeMemories: RouteMemoryStoring = DefaultRouteMemoryStore.shared,
        memoryCards: MemoryCardComposing = DefaultMemoryCardComposer.shared,
        placePhotos: PlacePhotoStoring = DefaultPlacePhotoStore.shared
    ) {
        self.badges = badges
        self.entitlements = entitlements
        self.ads = ads
        self.healthStats = healthStats
        self.savedRoutes = savedRoutes
        self.routeExporter = routeExporter
        self.analytics = analytics
        self.routeMemories = routeMemories
        self.memoryCards = memoryCards
        self.placePhotos = placePhotos
    }

    var isPro: Bool { entitlements.isPro }

    /// İlk rota tamamlanınca gösterilecek tek seferlik soft paywall hakkını tüketir:
    /// uygunsa bayrağı yakıp true döner. Karar ve bayrak yakma TEK çağrıda — bayrak
    /// yalnızca paywall gerçekten sunulacaksa yakılır (eskiden gösterim garantiye
    /// alınmadan yakılıyordu, hak boşa gidebiliyordu).
    func consumeSoftPaywallOffer(defaults: UserDefaults = .standard) -> Bool {
        guard !entitlements.isPro,
              !defaults.bool(forKey: "pinly.softPaywallShown") else { return false }
        defaults.set(true, forKey: "pinly.softPaywallShown")
        return true
    }

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

    func handleArrival(place: Place, stopIndex: Int, context: ModelContext, placeStore: PlaceRepository) {
        place.isVisited = true
        place.visitCount += 1
        try? context.save()
        placeStore.load(context: context)
        arrivedPlaceName = place.name
        pendingRatingPlace = place
        pendingRatingStopIndex = stopIndex
    }

    // MARK: - Anı Fotoğrafları (FAZ 3)

    /// Durak başına en fazla 3 foto. Çekilen foto ANINDA `RouteMemoryStoring`'e
    /// yazılır (rota tamamlanmadan app ölürse foto kaybolmasın). `alsoSaveAsPlacePhoto`
    /// açıksa aynı görsel AYRICA `PlacePhotoStoring`'e yazılıp mekânın galeri
    /// fotoğrafı yapılır — iki depo birbirinin dosyasına referans VERMEZ.
    @discardableResult
    func addMemoryPhoto(
        _ image: UIImage,
        stopIndex: Int,
        alsoSaveAsPlacePhoto: Bool,
        place: Place,
        context: ModelContext,
        placeStore: PlaceRepository
    ) -> Bool {
        guard (stopPhotos[stopIndex]?.count ?? 0) < 3 else { return false }
        guard let fileName = try? routeMemories.save(image, historyID: pendingHistoryID, stopIndex: stopIndex) else {
            return false
        }
        stopPhotos[stopIndex, default: []].append(fileName)
        analytics.track(.memoryPhotoAdded)

        if alsoSaveAsPlacePhoto, let placePhotoFileName = placePhotos.save(image) {
            place.photoFileName = placePhotoFileName
            try? context.save()
            placeStore.load(context: context)
        }
        return true
    }

    /// `stopPhotos`'u `RouteMemoryPhoto` dizisine çevirir — durak sırasına göre,
    /// isim kopyasıyla (Place silinse de günlük kartı ismi göstermeye devam eder).
    func memoryPhotos(routePlaces: [Place]) -> [RouteMemoryPhoto] {
        stopPhotos.keys.sorted().flatMap { stopIndex -> [RouteMemoryPhoto] in
            let stopName = stopIndex < routePlaces.count ? routePlaces[stopIndex].name : ""
            return (stopPhotos[stopIndex] ?? []).map { fileName in
                RouteMemoryPhoto(stopIndex: stopIndex, stopName: stopName, fileName: fileName)
            }
        }
    }

    private func loadedMemoryPhotoImages(routePlaces: [Place]) -> [UIImage] {
        memoryPhotos(routePlaces: routePlaces).compactMap { routeMemories.load(fileName: $0.fileName) }
    }

    /// "Hikayeni Paylaş" — anı kartını üretir (harita nil olabilir, örn. Günlük'ten
    /// "Yeniden Paylaş" akışında koordinat yoksa). `analytics.memoryCardShared` +
    /// rozet kaydı burada yapılır, View sadece haritayı üretip görseli paylaşır.
    func shareMemoryImage(
        format: MemoryShareFormat,
        routePlaces: [Place],
        fallbackRouteName: String,
        totalDistance: Double,
        totalTime: TimeInterval,
        mapSnapshot: UIImage?,
        placeStore: PlaceRepository
    ) -> UIImage {
        let history = RouteHistory(
            id: pendingHistoryID,
            routeName: exportRouteName(fallbackRouteName: fallbackRouteName),
            placeNames: routePlaces.map(\.name),
            totalDistanceMeters: totalDistance,
            durationSeconds: totalTime,
            stepCount: 0
        )
        let photos = loadedMemoryPhotoImages(routePlaces: routePlaces)
        analytics.track(.memoryCardShared(format: format.rawValue))
        let newBadges = recordRouteShared(placeStore: placeStore)
        placeStore.pendingBadges.append(contentsOf: newBadges)

        switch format {
        case .story: return memoryCards.composeStory(history: history, photos: photos, mapSnapshot: mapSnapshot)
        case .post:  return memoryCards.composePost(history: history, photos: photos, mapSnapshot: mapSnapshot)
        }
    }

    /// Günlük'te kayıtlı bir `RouteHistory`'den "Yeniden Paylaş" — koordinat
    /// saklanmadığı için harita İZİ YOKTUR (`mapSnapshot: nil`), kart yine de
    /// üretilir (bkz. MemoryCardComposing "harita nil'ken de kart üretmeli").
    func shareMemoryImage(format: MemoryShareFormat, history: RouteHistory) -> UIImage {
        let photos = history.memoryPhotos.compactMap { routeMemories.load(fileName: $0.fileName) }
        analytics.track(.memoryCardShared(format: format.rawValue))
        switch format {
        case .story: return memoryCards.composeStory(history: history, photos: photos, mapSnapshot: nil)
        case .post:  return memoryCards.composePost(history: history, photos: photos, mapSnapshot: nil)
        }
    }

    func recordRouteStarted() {
        badges.recordRouteStarted()
        analytics.track(.routeStarted)
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
        analytics.track(.routeCompleted)
        let newBadges = badges.check(placeStore: placeStore)

        let startDate = routeStartDate ?? Date()
        let endDate = Date()
        let name = exportRouteName(fallbackRouteName: fallbackRouteName)
        let placeNames = routePlaces.map(\.name)
        let catRaw = shareRouteCategory.rawValue

        let stats = await healthStats.fetchRouteStats(from: startDate, to: endDate)
        lastCompletionStepCount = stats.steps
        let history = RouteHistory(
            id: pendingHistoryID,
            routeName: name,
            placeNames: placeNames,
            totalDistanceMeters: totalDistance,
            durationSeconds: totalTime,
            stepCount: stats.steps,
            categoryRaw: catRaw
        )
        history.setMemoryPhotos(memoryPhotos(routePlaces: routePlaces))
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
        analytics.track(.routeShared)
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
