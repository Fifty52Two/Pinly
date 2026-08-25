import Foundation
import CoreLocation
import SwiftData

// MARK: - SavedRoutesViewModel
//
// SavedRoutesView'ın iş mantığı: uzaklık kontrolü, rota yükleme/başlatma, silme.
// PlacesListViewModel deseninin devamı — stateful/oturuma özel bağımlılıklar
// (RouteManager, ModelContext) constructor'da tutulmaz, ilgili metodlara
// parametre olarak geçirilir.

@MainActor
final class SavedRoutesViewModel: ObservableObject {
    @Published var pendingRoute: SavedRoute? = nil
    @Published var distanceText = ""
    @Published var routeToDelete: SavedRoute? = nil
    @Published var routeToEdit: SavedRoute? = nil

    // MARK: Sosyal yayınlama (FAZ 5 V2)

    /// Yayınlama isteği kullanıcı adı gerektiriyorsa true olur (bkz. `requireUsername`).
    @Published var showUsernameSetup = false
    @Published var isPublishing = false
    @Published var publishErrorMessage: String?
    /// Başarılı yayın sonrası kısa bir onay mesajı göstermek için rota adı.
    @Published var publishedRouteName: String?

    private let savedRoutes: SavedRouteRepository
    private let badges: BadgeServicing
    private let analytics: AnalyticsTracking
    private let social: SocialServicing
    private var pendingAction: (() -> Void)?

    init(
        savedRoutes: SavedRouteRepository = DefaultSavedRouteRepository.shared,
        badges: BadgeServicing = DefaultBadgeService.shared,
        analytics: AnalyticsTracking = RuntimeAnalyticsService.shared,
        social: SocialServicing = SocialFeaturePolicy.socialService
    ) {
        self.savedRoutes = savedRoutes
        self.badges = badges
        self.analytics = analytics
        self.social = social
    }

    func distanceKm(from userLocation: CLLocation?, to route: SavedRoute) -> Double? {
        savedRoutes.distanceKm(from: userLocation, to: route)
    }

    /// Uzaklık 1 km'den fazlaysa true döner ve `pendingRoute`/`distanceText`'i doldurur —
    /// çağıran taraf bu durumda uzaklık uyarı alert'ini göstermeli.
    func handleStartRoute(_ route: SavedRoute, userLocation: CLLocation?) -> Bool {
        guard let dist = savedRoutes.distanceKm(from: userLocation, to: route), dist > 1 else {
            return false
        }
        let formatted = dist >= 10
            ? String(format: "%.0f km", dist)
            : String(format: "%.1f km", dist)
        distanceText = String(
            format: NSLocalizedString(
                "Rotanın başlangıç noktasına yaklaşık %@ uzaktasınız. Yine de başlatmak istiyor musunuz?",
                comment: ""
            ),
            formatted
        )
        pendingRoute = route
        return true
    }

    /// Rota mekanlarını SwiftData'dan (varsa) eşleştirip navigasyon takipçisine yükler.
    func loadAndStart(_ route: SavedRoute, into tracker: RouteNavigationTracking, context: ModelContext) {
        let snapshots = route.placeSnapshots.sorted { $0.sortIndex < $1.sortIndex }
        let allPlaces = (try? context.fetch(FetchDescriptor<Place>())) ?? []

        let places: [Place] = snapshots.map { snap in
            // Önce placeId ile eşleştir (kalıcı), yoksa isimle (eski kayıtlar/dış rotalar)
            if let existing = SnapshotPlaceResolver.resolve(snap, in: allPlaces) {
                return existing
            }
            // Geçici yer tutucu — koordinatları ayarla
            let temp = Place(
                name: snap.name,
                category: snap.category,
                address: snap.address,
                notes: snap.notes
            )
            temp.latitude = snap.latitude
            temp.longitude = snap.longitude
            return temp
        }

        tracker.setRoute(places: places, name: route.name)
        badges.recordRouteStarted()
        analytics.track(.routeStarted)
    }

    func delete(_ route: SavedRoute, context: ModelContext) {
        savedRoutes.delete(route, context: context)
    }

    // MARK: - Sosyal yayınlama (FAZ 5 V2)

    /// "Paylaş" swipe action'ının girişi (View'dan senkron çağrılır — sadece `publishAsync`'i
    /// bir Task içinde sarar). Testler `publishAsync`'i doğrudan `await` edebilir.
    func publish(_ route: SavedRoute, context: ModelContext) {
        Task { await publishAsync(route, context: context) }
    }

    /// Kullanıcı adı yoksa önce `UsernameSetupSheet` gösterilir (adı ayarlanınca
    /// `usernameSetupSucceeded()` bekleyen yayını devam ettirir); adı zaten varsa doğrudan
    /// yayınlar. Başarılı olursa `SavedRoute.supabaseId` + `isPublic` yazılır ve context kaydedilir.
    func publishAsync(_ route: SavedRoute, context: ModelContext) async {
        if let profile = try? await social.myProfile(), profile.username != nil {
            await performPublish(route, context: context)
        } else {
            pendingAction = { [weak self] in
                Task { await self?.performPublish(route, context: context) }
            }
            showUsernameSetup = true
        }
    }

    /// Kullanıcı adı gate'ini atlayıp doğrudan yayın mantığını çalıştırır — testte
    /// gate'ten bağımsız olarak başarı/hata dallarını doğrulamak için de kullanılır.
    func performPublish(_ route: SavedRoute, context: ModelContext) async {
        isPublishing = true
        publishErrorMessage = nil
        do {
            let id = try await social.publish(route)
            route.supabaseId = id
            route.isPublic = true
            try? context.save()
            analytics.track(.routePublished)
            badges.recordRouteShared()
            publishedRouteName = route.name
        } catch SocialServiceError.cityUnresolved {
            publishErrorMessage = NSLocalizedString(
                "Rotanın şehri belirlenemedi, bu yüzden yayınlanamadı. Rotanın mekanlarında geçerli koordinat olduğundan emin ol.",
                comment: ""
            )
        } catch {
            publishErrorMessage = NSLocalizedString("Rota yayınlanamadı, tekrar dene.", comment: "")
        }
        isPublishing = false
    }

    func usernameSetupSucceeded() {
        showUsernameSetup = false
        let action = pendingAction
        pendingAction = nil
        action?()
    }
}
