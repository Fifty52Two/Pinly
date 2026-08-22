import Foundation
import Supabase

// MARK: - SharedRouteServicing

/// İki kişinin birlikte, gerçek zamanlı düzenlediği rota — ekleme/çıkarma/sıra değiştirme her
/// iki tarafta da anında görünür (Supabase Realtime `postgres_changes`). Kimlik `AppleAuthService`
/// üzerinden gelir; giriş yapılmamışsa (anonim oturum) çağıran taraf önce girişe yönlendirmeli.
protocol SharedRouteServicing {
    func create(name: String, category: String, places: [SavedPlaceSnapshot]) async throws -> SharedRouteDTO
    func fetch(id: String) async throws -> SharedRouteDTO
    /// Paylaşım linkini açan ikinci kişi için — `collaborator` boşsa kendini yazar, doluysa
    /// (zaten katılmışsa) mevcut satırı döner. Sahibin kendisi çağırırsa da satırı döner.
    @discardableResult
    func join(id: String) async throws -> SharedRouteDTO
    func update(id: String, name: String?, places: [SavedPlaceSnapshot]?) async throws
    /// Değişiklik geldikçe `onChange` MainActor'da çağrılır. Dönen `SharedRouteSubscription`
    /// nesnesi CANLI TUTULMALI (deinit olunca abonelik sessizce iptal olur).
    func subscribe(id: String, onChange: @escaping @MainActor (SharedRouteDTO) -> Void) -> SharedRouteSubscription
    /// Katıldığım TÜM ortak rotalar (sahibi olduğum + davetle katıldığım) — RLS zaten sadece
    /// erişimim olanları döner. Linki hiç paylaşmadan/kaydetmeden editor'ü kapatan kullanıcının
    /// rotaya geri dönebileceği TEK yol buydu (önceden hiç yoktu, "oluşturunca ekrandan
    /// kayboluyor" şikayetinin kaynağı).
    func myRoutes() async throws -> [SharedRouteDTO]
}

/// Realtime kanalını + token'ı saran küçük tutucu — ekran kapanınca `deinit` aboneliği keser.
final class SharedRouteSubscription {
    private let channel: RealtimeChannelV2
    private var subscriptionTask: Task<Void, Never>?

    fileprivate init(channel: RealtimeChannelV2) {
        self.channel = channel
    }

    fileprivate func start() {
        // `channel`'ı LOKAL değişkene alıp öyle yakalamak şart — `Task { self.channel... }`
        // gibi örtük `self` erişimi Task'ın kapanışına `self`'i GÜÇLÜ yakalatıyordu, bu da
        // `subscriptionTask` (self'in kendi stored property'si) → Task → kapanış → self
        // şeklinde bir retain cycle'a yol açıyordu. Nesne asla gerçek anlamda serbest
        // kalamıyor, sonraki erişimlerde "deallocated with non-zero retain count" / dangling
        // reference çöküyordu (gerçek cihazda görülen SIGABRT'in kaynağı buydu).
        let channel = self.channel
        subscriptionTask = Task { try? await channel.subscribeWithError() }
    }

    func cancel() {
        subscriptionTask?.cancel()
        let channel = self.channel
        Task { await channel.unsubscribe() }
    }

    deinit {
        cancel()
    }
}

// MARK: - SupabaseSharedRouteService

final class SupabaseSharedRouteService: SharedRouteServicing {
    static let shared = SupabaseSharedRouteService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SocialConfig.client) {
        self.client = client
    }

    func create(name: String, category: String, places: [SavedPlaceSnapshot]) async throws -> SharedRouteDTO {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw SocialServiceError.publishFailed
        }
        let payload = SharedRouteInsert(name: name, category: category, places: places, owner: userId, updatedBy: userId)
        let inserted: [SharedRouteDTO] = try await client.from("shared_routes")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let route = inserted.first else { throw SocialServiceError.publishFailed }
        return route
    }

    func fetch(id: String) async throws -> SharedRouteDTO {
        try await client.from("shared_routes")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    @discardableResult
    func join(id: String) async throws -> SharedRouteDTO {
        try await client.rpc("join_shared_route", params: ["target_id": id])
            .execute()
            .value
    }

    func update(id: String, name: String?, places: [SavedPlaceSnapshot]?) async throws {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw SocialServiceError.publishFailed
        }
        let payload = SharedRouteUpdate(name: name, places: places, updatedBy: userId)
        try await client.from("shared_routes")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func myRoutes() async throws -> [SharedRouteDTO] {
        try await client.from("shared_routes")
            .select()
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func subscribe(id: String, onChange: @escaping @MainActor (SharedRouteDTO) -> Void) -> SharedRouteSubscription {
        let channel = client.realtimeV2.channel("shared_routes:\(id)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds

        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "shared_routes",
            filter: .eq("id", value: id)
        ) { action in
            guard let route = try? action.decodeRecord(as: SharedRouteDTO.self, decoder: decoder) else { return }
            Task { @MainActor in onChange(route) }
        }

        let subscription = SharedRouteSubscription(channel: channel)
        subscription.start()
        return subscription
    }
}

// MARK: - NoOpSharedRouteService

/// Preview/test varsayılanı — Analytics/Social'daki NoOp deseninin devamı, canlı ağ isteği/
/// gerçek Supabase oturumu istemeyen bağlamlarda kullanılır.
final class NoOpSharedRouteService: SharedRouteServicing {
    static let shared = NoOpSharedRouteService()

    func create(name: String, category: String, places: [SavedPlaceSnapshot]) async throws -> SharedRouteDTO {
        SharedRouteDTO(
            id: UUID().uuidString, name: name, category: category, places: places,
            owner: "", collaborator: nil, updatedBy: nil, createdAt: Date(), updatedAt: Date()
        )
    }
    func fetch(id: String) async throws -> SharedRouteDTO {
        SharedRouteDTO(
            id: id, name: "", category: "city", places: [],
            owner: "", collaborator: nil, updatedBy: nil, createdAt: Date(), updatedAt: Date()
        )
    }
    @discardableResult
    func join(id: String) async throws -> SharedRouteDTO { try await fetch(id: id) }
    func update(id: String, name: String?, places: [SavedPlaceSnapshot]?) async throws {}
    func subscribe(id: String, onChange: @escaping @MainActor (SharedRouteDTO) -> Void) -> SharedRouteSubscription {
        SharedRouteSubscription(channel: SocialConfig.client.realtimeV2.channel("noop"))
    }
    func myRoutes() async throws -> [SharedRouteDTO] { [] }
}

private extension JSONDecoder.DateDecodingStrategy {
    /// Supabase Realtime `commit_timestamp`/`updated_at` kesirli saniye içerebiliyor —
    /// düz `.iso8601` bunu reddeder.
    static let iso8601WithFractionalSeconds = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Geçersiz tarih: \(string)")
    }
}
