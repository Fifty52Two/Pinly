import Foundation
import FirebaseAnalytics

// MARK: - AnalyticsTracking

/// Mekan ekleme kaynağı — `place_added` event'inin `source` parametresi.
enum PlaceAddSource: String, Equatable {
    case manual
    case qr
    case deeplink
    case swarm
    case nearby
    case quickAdd = "quick_add"
    case routeImport = "route_import"
}

/// Temel analytics event seti (RELEASE_PLAN FAZ 1.5).
/// İsim/parametreler Firebase `logEvent` sözleşmesine uygun (snake_case).
enum AnalyticsEvent: Equatable {
    case onboardingComplete
    case placeAdded(source: PlaceAddSource)
    case firstPlaceAdded(source: PlaceAddSource)
    case routeCreated
    case routeStarted
    case routeCompleted
    case routeShared
    case paywallShown(source: String)
    case nearbySearch(category: String)
    case trialStarted(product: String)
    case purchaseStarted(product: String)
    case purchaseCompleted(product: String)
    case restoreCompleted
    case exportGPX
    case exportPDF
    /// FAZ 4 "İlk 30 Saniye" akışı: kullanıcı hazır rota kataloğundan ya da Yakınımda
    /// fallback'inden bir rotayı kabul etti. `source`: katalog rota id'si ya da "nearby_fallback".
    case starterRouteAdopted(source: String)
    /// Anı Günlüğü (FAZ 3): durakta anı fotoğrafı eklendi.
    case memoryPhotoAdded
    /// Anı Günlüğü (FAZ 3): rota tamamlama kartı paylaşıldı — format "story"/"post".
    case memoryCardShared(format: String)
    /// Sosyal katman (FAZ 5 V2): kayıtlı bir rota topluluk feed'ine yayınlandı.
    case routePublished
    /// Sosyal katman (FAZ 5 V2): feed'de bir rota favlandı.
    case routeFavorited

    var name: String {
        switch self {
        case .onboardingComplete: return "onboarding_complete"
        case .placeAdded:         return "place_added"
        case .firstPlaceAdded:    return "first_place_added"
        case .routeCreated:       return "route_created"
        case .routeStarted:       return "route_started"
        case .routeCompleted:     return "route_completed"
        case .routeShared:        return "route_shared"
        case .paywallShown:       return "paywall_viewed"
        case .nearbySearch:       return "nearby_search"
        case .trialStarted:       return "trial_started"
        case .purchaseStarted:    return "purchase_started"
        case .purchaseCompleted:  return "purchase_completed"
        case .restoreCompleted:   return "restore_completed"
        case .exportGPX:          return "export_gpx"
        case .exportPDF:          return "export_pdf"
        case .starterRouteAdopted: return "starter_route_adopted"
        case .memoryPhotoAdded:   return "memory_photo_added"
        case .memoryCardShared:   return "memory_card_shared"
        case .routePublished:     return "route_published"
        case .routeFavorited:     return "route_favorited"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .placeAdded(let source), .firstPlaceAdded(let source): return ["source": source.rawValue]
        case .nearbySearch(let category):  return ["category": category]
        case .paywallShown(let source):    return ["source": source]
        case .trialStarted(let product),
             .purchaseStarted(let product),
             .purchaseCompleted(let product): return ["product": product]
        case .starterRouteAdopted(let source): return ["source": source]
        case .memoryCardShared(let format): return ["format": format]
        default:                           return [:]
        }
    }
}

/// Analytics soyutlaması. Firebase Analytics entegre olunca (FAZ 1.2-1.3) SADECE
/// somut implementasyon değişir (`FirebaseAnalyticsService: AnalyticsTracking`),
/// çağıran yerler sabit kalır — EntitlementService/RevenueCat deseniyle aynı.
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

// MARK: - RuntimeAnalyticsService

/// `@StateObject` ViewModel'ler SwiftUI environment kurulmadan önce oluşturulduğu için
/// constructor varsayılanlarının doğrudan NoOp olması production event'lerini sessizce
/// kaybettiriyordu. Bu router tüm varsayılanların tek, sonradan yapılandırılan hedefe gitmesini
/// sağlar; testler yine doğrudan mock enjekte eder.
final class RuntimeAnalyticsService: AnalyticsTracking {
    static let shared = RuntimeAnalyticsService()

    private let lock = NSLock()
    private var destination: AnalyticsTracking = NoOpAnalyticsService.shared

    func configure(destination: AnalyticsTracking) {
        lock.lock()
        self.destination = destination
        lock.unlock()
    }

    func track(_ event: AnalyticsEvent) {
        lock.lock()
        let destination = self.destination
        lock.unlock()
        destination.track(event)
    }
}

// MARK: - NoOpAnalyticsService

/// Firebase eklenmeden önceki varsayılan implementasyon: hiçbir yere göndermez,
/// DEBUG derlemede konsola yazar. Artık sadece testlerde/preview'larda kullanılır —
/// gerçek uygulama composition root'ta `FirebaseAnalyticsService` kullanır.
final class NoOpAnalyticsService: AnalyticsTracking {
    static let shared = NoOpAnalyticsService()

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let params = event.parameters.isEmpty ? "" : " \(event.parameters)"
        print("📊 analytics: \(event.name)\(params)")
        #endif
    }
}

// MARK: - FirebaseAnalyticsService

/// Firebase Analytics'e loglayan gerçek implementasyon (FAZ 1.2-1.3).
/// `FirebaseApp.configure()` `PinlyApp.init()`'te çağrılmış olmalı.
final class FirebaseAnalyticsService: AnalyticsTracking {
    static let shared = FirebaseAnalyticsService()

    private let firstPlaceTrackedKey = "pinly.analytics.firstPlaceTracked"

    func track(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters.isEmpty ? nil : event.parameters)
        if case .placeAdded(let source) = event,
           !UserDefaults.standard.bool(forKey: firstPlaceTrackedKey) {
            UserDefaults.standard.set(true, forKey: firstPlaceTrackedKey)
            let firstEvent = AnalyticsEvent.firstPlaceAdded(source: source)
            Analytics.logEvent(firstEvent.name, parameters: firstEvent.parameters)
        }
        #if DEBUG
        let params = event.parameters.isEmpty ? "" : " \(event.parameters)"
        print("📊 analytics: \(event.name)\(params)")
        #endif
    }
}
