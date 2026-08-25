import Foundation
import Combine
import RevenueCat

// MARK: - EntitlementProviding

/// Pro üyelik / freemium limit kararlarının tek kaynağı.
/// View'lar bu protokole `@Environment(\.entitlements)` üzerinden erişir.
protocol EntitlementProviding: AnyObject {
    var isPro: Bool { get set }
    func canAddPlace(currentCount: Int) -> Bool
}

// MARK: - LocalEntitlementService

/// UserDefaults tabanlı yerel implementasyon — DEBUG build'lerinde ve
/// `RevenueCatEntitlementService`'in `pinly.isPro` aynasını okuyan
/// ViewModel default'larında kullanılır (bkz. `RevenueCatEntitlementService`).
/// Release'te gerçeğin kaynağı RevenueCat'tir (bkz. `PinlyApp`).
final class LocalEntitlementService: EntitlementProviding, ObservableObject {
    static let shared = LocalEntitlementService()

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
        // Mekan ekleme artık ücretsiz ve sınırsız — Pro değer önerisi GPX/PDF + reklamsız.
        return true
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

    private let proMirrorKey = "pinly.isPro"
    private let defaults: UserDefaults
    private var listenTask: Task<Void, Never>?

    @Published private var isProValue: Bool

    /// Setter yalnızca Paywall'ın RevenueCat'ten dönen doğrulanmış `CustomerInfo` sonucunu
    /// anında yansıtması için kullanılır. Stream yine uzun ömürlü gerçek kaynak olarak aynayı
    /// sonraki SDK güncellemelerinde düzeltir.
    var isPro: Bool {
        get { isProValue }
        set {
            guard newValue != isProValue else { return }
            isProValue = newValue
            defaults.set(newValue, forKey: proMirrorKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isProValue = defaults.bool(forKey: proMirrorKey)
        guard RevenueCatConfig.configureIfNeeded() else { return }
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
        // Mekan ekleme artık ücretsiz ve sınırsız — Pro değer önerisi GPX/PDF + reklamsız.
        return true
    }
}
