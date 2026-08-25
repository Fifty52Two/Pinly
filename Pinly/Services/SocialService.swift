import Foundation
import CoreLocation
import Supabase

// MARK: - SocialConfig

/// `SupabaseClient` tekil kaynağı. URL/publishable key Info.plist'ten okunur — RevenueCat'teki
/// `RevenueCatConfig` deseniyle aynı (bkz. PurchasesService.swift). Publishable key client-safe
/// (anon role, RLS ile korunur); service role key BURADA YOK, asla client'a girmez.
enum SocialConfig {
    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString),
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String
        else {
            preconditionFailure("Supabase yapılandırması Info.plist'te eksik (SupabaseURL/SupabasePublishableKey)")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}

// MARK: - SocialServiceError

enum SocialServiceError: LocalizedError {
    /// V1 composition root sosyal özelliği bilerek kapalı tutar. NoOp servisler mutasyonları
    /// sahte başarıyla yutmak yerine bu hatayla fail-closed davranır.
    case disabled
    /// Rota merkezinin şehir/ülkesi reverse-geocode ile çözülemedi (city NOT NULL kısıtı).
    case cityUnresolved
    case publishFailed
    /// Client-side rate limit — çok sık tekrarlanan mutasyon (OWASP A04).
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .disabled:       return NSLocalizedString("Topluluk özellikleri bu sürümde kullanılamıyor.", comment: "")
        case .cityUnresolved: return NSLocalizedString("Rota konumu belirlenemedi.", comment: "")
        case .publishFailed:  return NSLocalizedString("Rota yayınlanamadı.", comment: "")
        case .rateLimited:    return NSLocalizedString("Çok hızlı istekte bulundunuz, lütfen bekleyin.", comment: "")
        }
    }
}

// MARK: - RouteFeedProviding

/// Sosyal rota feed'i: yayınlama/favlama/bildirme/engelleme. Anonim Supabase oturumu SADECE
/// implementasyon (SupabaseSocialService) içinde, ilk çağrıda görünmez şekilde açılır —
/// kullanıcı hiçbir ek adım görmez (bkz. specs/FAZ5_SUPABASE_MIMARI.md "hesap sürtünmesi sıfır").
protocol RouteFeedProviding {
    func fetchFeed(city: String, cursor: Date?) async throws -> [PublicRouteDTO]
    @discardableResult
    func publish(_ route: SavedRoute) async throws -> String
    func favorite(routeId: String) async throws
    func unfavorite(routeId: String) async throws
    func myFavorites() async throws -> [PublicRouteDTO]
    /// Kendi yayınladığım rotalar (her status) — Kamu Profili ekranında yayın sayısı +
    /// toplam alınan fav'i hesaplamak için (`profile_stats` view'ı henüz yok, client-side
    /// toplanıyor). RLS: `public_routes` select politikası zaten "kendi satırları her status'te".
    func myPublishedRoutes() async throws -> [PublicRouteDTO]
    func report(routeId: String, reason: ReportReason, note: String?) async throws
    func block(userId: String) async throws
}

// MARK: - ProfileSyncing

protocol ProfileSyncing {
    /// Cihazda ZATEN bir Supabase oturumu var mı — senkron, ağa çıkmaz. Ekranların "sosyal
    /// katmana hiç dokunulmadıysa myProfile() bile çağırma" kontrolü için (ör. ProfileTab her
    /// açılışta bunu kontrol eder; aksi halde myProfile() ensureSession() üzerinden HERKESTE
    /// sessizce anonim hesap açardı — "hesap sürtünmesi sıfır" ilkesi yalnızca UI'da değil,
    /// arka planda hesap oluşturmama sözü de verir).
    var hasLocalSession: Bool { get }
    func myProfile() async throws -> SocialProfileDTO?
    func publicProfile(id: String) async throws -> SocialProfileDTO?
    /// Kullanıcı adı sadece ilk yayınlama/favlama anında istenir; bu çağrı o formun submit'i.
    /// 30 günde bir değişim sınırı ve küfür filtresi DB trigger'larında uygulanır.
    func setUsername(_ username: String) async throws
}

typealias SocialServicing = RouteFeedProviding & ProfileSyncing

// MARK: - SupabaseSocialService

final class SupabaseSocialService: RouteFeedProviding, ProfileSyncing {
    static let shared = SupabaseSocialService()

    private let client: SupabaseClient
    private let geocoding: GeocodingProviding

    /// Client-side rate limiting — mutating çağrıları (publish, favorite)
    /// kısa aralıklarda tekrar tetiklemeyi önler (OWASP A04).
    private var lastMutationTimestamps: [String: Date] = [:]
    private let mutationCooldown: TimeInterval = 2.0

    init(
        client: SupabaseClient = SocialConfig.client,
        geocoding: GeocodingProviding = DefaultGeocodingService.shared
    ) {
        self.client = client
        self.geocoding = geocoding
    }

    /// Rate limit kontrolü — aynı aksiyon `mutationCooldown` saniye içinde
    /// tekrar çağrılırsa false döner.
    private func checkRateLimit(action: String) -> Bool {
        let now = Date()
        if let last = lastMutationTimestamps[action],
           now.timeIntervalSince(last) < mutationCooldown {
            return false
        }
        lastMutationTimestamps[action] = now
        return true
    }

    /// Var olan oturumu kullanır; yoksa anonim oturum sessizce açılır. `currentUser` local'de
    /// saklanan (Keychain-backed) oturumu senkron döndürür — feed'i her açışta ağa gitmeden
    /// tekrar sign-in denemez.
    @discardableResult
    private func ensureSession() async throws -> String {
        if let user = client.auth.currentUser {
            return user.id.uuidString
        }
        let session = try await client.auth.signInAnonymously()
        return session.user.id.uuidString
    }

    // MARK: RouteFeedProviding

    func fetchFeed(city: String, cursor: Date?) async throws -> [PublicRouteDTO] {
        try await ensureSession()
        var filterQuery = client.from("public_routes")
            .select()
            .eq("city", value: city.lowercased())
            .eq("status", value: "active")
        if let cursor {
            filterQuery = filterQuery.lt("created_at", value: cursor)
        }
        let query = filterQuery
            .order("is_official", ascending: false)
            .order("fav_count", ascending: false)
            .order("created_at", ascending: false)
            .limit(20)
        return try await query.execute().value
    }

    @discardableResult
    func publish(_ route: SavedRoute) async throws -> String {
        guard checkRateLimit(action: "publish") else { throw SocialServiceError.rateLimited }
        let owner = try await ensureSession()
        let coordinate = CLLocationCoordinate2D(
            latitude: route.centerLatitude,
            longitude: route.centerLongitude
        )
        guard
            let placemark = await geocoding.reverseGeocode(coordinate: coordinate),
            let city = placemark.locality?.lowercased(),
            let country = placemark.isoCountryCode?.lowercased()
        else {
            throw SocialServiceError.cityUnresolved
        }

        let snapshots = route.placeSnapshots
        let payload = PublicRouteInsert(
            owner: owner,
            name: route.name,
            description: nil,
            city: city,
            country: country,
            category: route.categoryRaw ?? RouteCategory.city.rawValue,
            places: snapshots,
            centerLat: route.centerLatitude,
            centerLon: route.centerLongitude,
            distanceKm: nil,
            stopCount: max(snapshots.count, 2)
        )

        struct InsertedRow: Decodable { let id: String }
        let inserted: [InsertedRow] = try await client.from("public_routes")
            .insert(payload)
            .select("id")
            .execute()
            .value
        guard let id = inserted.first?.id else { throw SocialServiceError.publishFailed }
        return id
    }

    func favorite(routeId: String) async throws {
        guard checkRateLimit(action: "favorite_\(routeId)") else { return }
        let userId = try await ensureSession()
        struct FavoriteInsert: Encodable {
            let userId: String
            let routeId: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case routeId = "route_id"
            }
        }
        try await client.from("favorites")
            .insert(FavoriteInsert(userId: userId, routeId: routeId))
            .execute()
    }

    func unfavorite(routeId: String) async throws {
        let userId = try await ensureSession()
        try await client.from("favorites")
            .delete()
            .eq("user_id", value: userId)
            .eq("route_id", value: routeId)
            .execute()
    }

    func myFavorites() async throws -> [PublicRouteDTO] {
        let userId = try await ensureSession()
        struct FavoriteRow: Decodable {
            let publicRoutes: PublicRouteDTO
            enum CodingKeys: String, CodingKey {
                case publicRoutes = "public_routes"
            }
        }
        let rows: [FavoriteRow] = try await client.from("favorites")
            .select("public_routes(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map(\.publicRoutes)
    }

    func myPublishedRoutes() async throws -> [PublicRouteDTO] {
        let owner = try await ensureSession()
        return try await client.from("public_routes")
            .select()
            .eq("owner", value: owner)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func report(routeId: String, reason: ReportReason, note: String?) async throws {
        let reporter = try await ensureSession()
        struct ReportInsert: Encodable {
            let reporter: String
            let routeId: String
            let reason: String
            let note: String?
            enum CodingKeys: String, CodingKey {
                case reporter, reason, note
                case routeId = "route_id"
            }
        }
        try await client.from("reports")
            .insert(ReportInsert(reporter: reporter, routeId: routeId, reason: reason.rawValue, note: note))
            .execute()
    }

    func block(userId: String) async throws {
        let blocker = try await ensureSession()
        struct BlockInsert: Encodable {
            let blocker: String
            let blocked: String
        }
        try await client.from("blocks")
            .insert(BlockInsert(blocker: blocker, blocked: userId))
            .execute()
    }

    // MARK: ProfileSyncing

    var hasLocalSession: Bool { client.auth.currentUser != nil }

    func myProfile() async throws -> SocialProfileDTO? {
        let userId = try await ensureSession()
        let rows: [SocialProfileDTO] = try await client.from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        return rows.first
    }

    func publicProfile(id: String) async throws -> SocialProfileDTO? {
        try await ensureSession()
        let rows: [SocialProfileDTO] = try await client.from("profiles")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        return rows.first
    }

    func setUsername(_ username: String) async throws {
        let userId = try await ensureSession()
        struct ProfileUpsert: Encodable {
            let id: String
            let username: String
        }
        try await client.from("profiles")
            .upsert(ProfileUpsert(id: userId, username: username))
            .execute()
    }
}

// MARK: - NoOpSocialService

/// Preview/test + "sosyal katman devre dışı" fallback — hiçbir çağrı ağa çıkmaz, oturum açmaz.
final class NoOpSocialService: RouteFeedProviding, ProfileSyncing {
    static let shared = NoOpSocialService()

    func fetchFeed(city: String, cursor: Date?) async throws -> [PublicRouteDTO] { [] }
    @discardableResult
    func publish(_ route: SavedRoute) async throws -> String { throw SocialServiceError.disabled }
    func favorite(routeId: String) async throws { throw SocialServiceError.disabled }
    func unfavorite(routeId: String) async throws { throw SocialServiceError.disabled }
    func myFavorites() async throws -> [PublicRouteDTO] { [] }
    func myPublishedRoutes() async throws -> [PublicRouteDTO] { [] }
    func report(routeId: String, reason: ReportReason, note: String?) async throws { throw SocialServiceError.disabled }
    func block(userId: String) async throws { throw SocialServiceError.disabled }
    var hasLocalSession: Bool { false }
    func myProfile() async throws -> SocialProfileDTO? { nil }
    func publicProfile(id: String) async throws -> SocialProfileDTO? { nil }
    func setUsername(_ username: String) async throws { throw SocialServiceError.disabled }
}
