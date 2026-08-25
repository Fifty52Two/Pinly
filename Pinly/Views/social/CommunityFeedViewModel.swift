import Foundation

// MARK: - CommunityFeedViewModel
//
// CommunityFeedView'ın iş mantığı: şehre göre feed çekme + keyset pagination, favlama
// (kullanıcı adı yoksa önce UsernameSetupSheet), engelleme. `SavedRoutesViewModel` deseninin
// devamı — sadece varsayılan singleton'ı olan servisler (`social`/`analytics`) constructor
// injection ile alınır.

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    @Published var city: String = ""
    @Published var routes: [PublicRouteDTO] = []
    @Published var favoritedRouteIds: Set<String> = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    /// Favlama ilk sosyal aksiyonsa kullanıcı adı sorulur (bkz. UsernameSetupSheet).
    @Published var showUsernameSetup = false

    /// Bir kullanıcıyı engelledikten sonra o kullanıcının rotalarını feed'den anında düşürmek için.
    @Published var blockedOwnerIds: Set<String> = []

    private let social: SocialServicing
    private let analytics: AnalyticsTracking
    private var pendingAction: (() -> Void)?

    init(
        social: SocialServicing = SocialFeaturePolicy.socialService,
        analytics: AnalyticsTracking = RuntimeAnalyticsService.shared
    ) {
        self.social = social
        self.analytics = analytics
    }

    var visibleRoutes: [PublicRouteDTO] {
        routes.filter { !blockedOwnerIds.contains($0.owner) }
    }

    // MARK: - Feed yükleme

    func loadInitial(city: String) async {
        guard !city.isEmpty else { return }
        self.city = city
        isLoading = true
        errorMessage = nil
        hasMore = true
        do {
            let fetched = try await social.fetchFeed(city: city, cursor: nil)
            routes = fetched
            hasMore = fetched.count >= 20
        } catch {
            errorMessage = NSLocalizedString("Topluluk rotaları yüklenemedi. Bağlantını kontrol edip tekrar dene.", comment: "")
        }
        isLoading = false
        await refreshMyFavorites()
    }

    func loadMoreIfNeeded(currentItem: PublicRouteDTO) async {
        guard hasMore, !isLoadingMore, currentItem.id == routes.last?.id else { return }
        isLoadingMore = true
        do {
            let fetched = try await social.fetchFeed(city: city, cursor: routes.last?.createdAt)
            routes.append(contentsOf: fetched)
            hasMore = fetched.count >= 20
        } catch {
            // Sessiz — kullanıcı zaten scroll ediyor, alt kısımda hata banner'ı gösterip
            // akışı bölmeye gerek yok; tekrar scroll edince yeniden dener.
            hasMore = false
        }
        isLoadingMore = false
    }

    func refreshMyFavorites() async {
        guard let favorites = try? await social.myFavorites() else { return }
        favoritedRouteIds = Set(favorites.map(\.id))
    }

    // MARK: - Favlama (kullanıcı adı gate'i)

    /// View'dan senkron çağrılır (buton action) — asıl mantık `toggleFavoriteAsync`'te,
    /// testler onu doğrudan `await` edebilir.
    func toggleFavorite(_ route: PublicRouteDTO) {
        Task { await toggleFavoriteAsync(route) }
    }

    func toggleFavoriteAsync(_ route: PublicRouteDTO) async {
        if let profile = try? await social.myProfile(), profile.username != nil {
            await performToggleFavorite(route)
        } else {
            pendingAction = { [weak self] in
                Task { await self?.performToggleFavorite(route) }
            }
            showUsernameSetup = true
        }
    }

    /// Kullanıcı adı gate'ini atlayıp doğrudan fav toggle mantığını çalıştırır.
    func performToggleFavorite(_ route: PublicRouteDTO) async {
        let isFavorited = favoritedRouteIds.contains(route.id)
        // İyimser güncelleme — sunucu fav_count'u trigger'la tuttuğu için tam senkron
        // gerekmez, kullanıcı anında geri bildirim görür.
        if isFavorited {
            favoritedRouteIds.remove(route.id)
            updateFavCount(routeId: route.id, delta: -1)
        } else {
            favoritedRouteIds.insert(route.id)
            updateFavCount(routeId: route.id, delta: 1)
            analytics.track(.routeFavorited)
        }
        do {
            if isFavorited {
                try await social.unfavorite(routeId: route.id)
            } else {
                try await social.favorite(routeId: route.id)
            }
        } catch {
            // Başarısızsa iyimser güncellemeyi geri al.
            if isFavorited {
                favoritedRouteIds.insert(route.id)
                updateFavCount(routeId: route.id, delta: 1)
            } else {
                favoritedRouteIds.remove(route.id)
                updateFavCount(routeId: route.id, delta: -1)
            }
        }
    }

    private func updateFavCount(routeId: String, delta: Int) {
        guard let index = routes.firstIndex(where: { $0.id == routeId }) else { return }
        routes[index].favCount = max(0, routes[index].favCount + delta)
    }

    // MARK: - Engelleme

    func block(userId: String) async {
        blockedOwnerIds.insert(userId)
        try? await social.block(userId: userId)
    }

    // MARK: - Kullanıcı adı gate'i

    func usernameSetupSucceeded() {
        showUsernameSetup = false
        let action = pendingAction
        pendingAction = nil
        action?()
    }
}
