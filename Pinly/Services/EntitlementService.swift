import Foundation
import Combine
import RevenueCat

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
        // TestFlight betasında limit uygulanmaz — paywall gate'leri hiç tetiklenmez
        // (FAZ 6.1; RevenueCat gelince kaldırılacak)
        if FeatureFlags.unlimitedPlacesInBeta { return true }
        return isPro || currentCount < freeLimit
    }
}

// MARK: - RevenueCatEntitlementService

/// RevenueCat destekli üyelik servisi — App Store build'inde gerçeğin TEK kaynağı budur.
///
/// `isPro` composition root'ta `#if DEBUG` ile `LocalEntitlementService`'e karşı seçilir
/// (bkz. `PinlyApp`); bu sınıf yalnızca Release/TestFlight'ta aktiftir. `customerInfoStream`
/// dinlenir, sonuç `pinly.isPro` UserDefaults anahtarına AYNA olarak yazılır — hem uçak
/// modunda açılışta son bilinen değerle başlamak için hem de `LocalEntitlementService.shared`'ı
/// varsayılan olarak constructor-inject eden ViewModel'lerin (QuickAddViewModel,
/// QRScannerViewModel, RouteSummaryViewModel — DIP gereği environment'tan değil kendi
/// default'larından okurlar) aynı anahtarı okuyarak dolaylı biçimde güncel kalması için.
final class RevenueCatEntitlementService: EntitlementProviding, ObservableObject {
    static let shared = RevenueCatEntitlementService()

    let freeLimit = 20

    private let proMirrorKey = "pinly.isPro"
    private let defaults: UserDefaults
    private var listenTask: Task<Void, Never>?

    @Published private var isProValue: Bool

    /// Salt-okunur: gerçeğin kaynağı RevenueCat'tir, kimse elle Pro yapamaz.
    /// Yanlışlıkla çağrılırsa DEBUG'da assert eder (Release'te no-op, derlemede elenir).
    var isPro: Bool {
        get { isProValue }
        set {
            assertionFailure("RevenueCatEntitlementService.isPro salt-okunur — gerçek kaynak RevenueCat müşteri bilgisidir.")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isProValue = defaults.bool(forKey: proMirrorKey)
        RevenueCatConfig.configureIfNeeded()
        listenTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                await MainActor.run {
                    self.apply(customerInfo)
                }
            }
        }
    }

    deinit { listenTask?.cancel() }

    private func apply(_ customerInfo: CustomerInfo) {
        isProValue = EntitlementMapper.isPro(customerInfo: customerInfo)
        defaults.set(isProValue, forKey: proMirrorKey)
    }

    func canAddPlace(currentCount: Int) -> Bool {
        if FeatureFlags.unlimitedPlacesInBeta { return true }
        return isPro || currentCount < freeLimit
    }
}
