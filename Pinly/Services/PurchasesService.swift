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

    @discardableResult
    static func configureIfNeeded() -> Bool {
        if Purchases.isConfigured { return true }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        return true
    }
}

enum RevenueCatConfigurationError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return NSLocalizedString("Pinly Pro yapılandırması bu build'de mevcut değil.", comment: "")
        }
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
    /// Kullanıcının bu ürünün deneme/giriş fiyatına uygun olup olmadığı (App Store hesabı
    /// bazında — trial'ını daha önce kullanmış kullanıcı `.ineligible` döner).
    func checkTrialEligibility(product: StoreProduct) async -> IntroEligibilityStatus
}

// MARK: - RevenueCatPurchasesService

final class RevenueCatPurchasesService: PurchasesProviding {
    static let shared = RevenueCatPurchasesService()

    init() {
        RevenueCatConfig.configureIfNeeded()
    }

    func offerings() async throws -> Offerings {
        guard RevenueCatConfig.configureIfNeeded() else {
            throw RevenueCatConfigurationError.missingAPIKey
        }
        return try await Purchases.shared.offerings()
    }

    func purchase(package: Package) async throws -> (customerInfo: CustomerInfo, userCancelled: Bool) {
        guard RevenueCatConfig.configureIfNeeded() else {
            throw RevenueCatConfigurationError.missingAPIKey
        }
        let result = try await Purchases.shared.purchase(package: package)
        return (result.customerInfo, result.userCancelled)
    }

    func restorePurchases() async throws -> CustomerInfo {
        guard RevenueCatConfig.configureIfNeeded() else {
            throw RevenueCatConfigurationError.missingAPIKey
        }
        return try await Purchases.shared.restorePurchases()
    }

    func checkTrialEligibility(product: StoreProduct) async -> IntroEligibilityStatus {
        guard RevenueCatConfig.configureIfNeeded() else { return .unknown }
        return await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
    }
}
