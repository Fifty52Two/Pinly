import Foundation

// MARK: - PinlyLegal

/// Yasal doküman adreslerinin TEK kaynağı.
///
/// Otomatik yenilenen abonelik satan her paywall'da Gizlilik Politikası ve Kullanım
/// Koşulları bağlantıları fonksiyonel olmak ZORUNDA (App Store Guideline 3.1.2) — aynı
/// adresler App Store Connect'teki uygulama metadata'sına da girilir.
///
/// Host `Config.local.xcconfig` → Info.plist üzerinden gelir. Doğrulanmamış veya boş hostta
/// `nil` döner; uygulama başka ürüne ait/ölü bir domaini göstermemelidir. Release preflight
/// production host ve sayfaların erişilebilir olmasını ayrıca zorunlu tutar.
enum PinlyLegal {
    private static let websiteHost: String? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PinlyWebsiteHost") as? String else {
            return nil
        }
        let host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty,
              !host.contains("/"),
              !host.contains(":"),
              host.contains(".") else { return nil }
        return host
    }()

    private static func websiteURL(path: String) -> URL? {
        guard let websiteHost else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = websiteHost
        components.path = path
        return components.url
    }

    static let privacyPolicyURL = websiteURL(path: "/privacy/")
    static let termsOfUseURL = websiteURL(path: "/terms/")
    static let privacyChoicesURL = websiteURL(path: "/privacy-choices/")
    static let supportURL = websiteURL(path: "/support/")

    static let appStoreURL: URL? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PinlyAppStoreID") as? String else {
            return nil
        }
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }()
}
