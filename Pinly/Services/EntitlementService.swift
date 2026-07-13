import Foundation
import Combine

// MARK: - EntitlementProviding

/// Pro üyelik / freemium limit kararlarının tek kaynağı.
/// View'lar bu protokole `@Environment(\.entitlements)` üzerinden erişir.
protocol EntitlementProviding: AnyObject {
    var isPro: Bool { get set }
    var freeLimit: Int { get }
    func canAddPlace(currentCount: Int) -> Bool
}

// MARK: - LocalEntitlementService

/// UserDefaults tabanlı yerel implementasyon.
///
/// NOT: Apple Developer hesabı alınınca bu sınıf RevenueCat destekli bir
/// implementasyonla değiştirilecek (`Purchases.shared.cachedCustomerInfo?
/// .entitlements[entitlementID]?.isActive == true`). Protokol sabit kaldığı
/// için call site'lar değişmeyecek.
final class LocalEntitlementService: EntitlementProviding, ObservableObject {
    static let shared = LocalEntitlementService()

    let freeLimit = 20
    let entitlementID = "pro"

    private let proKey = "pinly.isPro"
    private let legacyProKey = "notiongo.isPro"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isPro: Bool {
        get {
            if defaults.object(forKey: proKey) != nil {
                return defaults.bool(forKey: proKey)
            }
            // Eski NotionGO anahtarından migrasyon
            let legacyValue = defaults.bool(forKey: legacyProKey)
            defaults.set(legacyValue, forKey: proKey)
            return legacyValue
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: proKey)
            defaults.removeObject(forKey: legacyProKey)
        }
    }

    func canAddPlace(currentCount: Int) -> Bool {
        isPro || currentCount < freeLimit
    }
}
