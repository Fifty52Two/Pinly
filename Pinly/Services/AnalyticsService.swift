import Foundation

// MARK: - AnalyticsTracking

/// Mekan ekleme kaynağı — `place_added` event'inin `source` parametresi.
enum PlaceAddSource: String {
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
enum AnalyticsEvent {
    case placeAdded(source: PlaceAddSource)
    case routeStarted
    case routeCompleted
    case routeShared
    case paywallShown
    case nearbySearch(category: String)

    var name: String {
        switch self {
        case .placeAdded:    return "place_added"
        case .routeStarted:  return "route_started"
        case .routeCompleted: return "route_completed"
        case .routeShared:   return "route_shared"
        case .paywallShown:  return "paywall_shown"
        case .nearbySearch:  return "nearby_search"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .placeAdded(let source):    return ["source": source.rawValue]
        case .nearbySearch(let category): return ["category": category]
        default:                          return [:]
        }
    }
}

/// Analytics soyutlaması. Firebase Analytics entegre olunca (FAZ 1.2-1.3) SADECE
/// somut implementasyon değişir (`FirebaseAnalyticsService: AnalyticsTracking`),
/// çağıran yerler sabit kalır — EntitlementService/RevenueCat deseniyle aynı.
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

// MARK: - NoOpAnalyticsService

/// Firebase eklenene kadar varsayılan implementasyon: hiçbir yere göndermez,
/// DEBUG derlemede konsola yazar (event akışını geliştirirken doğrulamak için).
final class NoOpAnalyticsService: AnalyticsTracking {
    static let shared = NoOpAnalyticsService()

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let params = event.parameters.isEmpty ? "" : " \(event.parameters)"
        print("📊 analytics: \(event.name)\(params)")
        #endif
    }
}
