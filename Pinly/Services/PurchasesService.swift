import Foundation
import RevenueCat

// MARK: - RevenueCatConfig

/// `Purchases.configure` çağrısını tek bir yerde toplar — hem PinlyApp (composition root)
/// hem de servislerin lazy `.shared` erişimi (ör. SwiftUI Preview) idempotent şekilde
/// aynı noktadan geçer, çifte configure crash'i (`Purchases has already been configured`) olmaz.
enum RevenueCatConfig {
    static let apiKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
    }()

    static func configureIfNeeded() {
        guard !Purchases.isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }
}

// MARK: - PurchasesProviding

/// PaywallView'un mağaza katmanına ihtiyacı: offering'i göster, satın al, geri yükle.
/// `EntitlementProviding`'ten ayrı tutulur — o yalnızca "isPro mu" sorusuna cevap verir,
/// bu protokol ise satın alma AKIŞININ kendisini kapsar.
protocol PurchasesProviding {
    func offerings() async throws -> Offerings
    func purchase(package: Package) async throws -> (customerInfo: CustomerInfo, userCancelled: Bool)
    func restorePurchases() async throws -> CustomerInfo
}

// MARK: - RevenueCatPurchasesService

final class RevenueCatPurchasesService: PurchasesProviding {
    static let shared = RevenueCatPurchasesService()

    init() {
        RevenueCatConfig.configureIfNeeded()
    }

    func offerings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    func purchase(package: Package) async throws -> (customerInfo: CustomerInfo, userCancelled: Bool) {
        let result = try await Purchases.shared.purchase(package: package)
        return (result.customerInfo, result.userCancelled)
    }

    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }
}
