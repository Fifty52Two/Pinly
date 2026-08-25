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
    static func validatedWebsiteHost(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              host.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              labels.allSatisfy({ !$0.isEmpty && !$0.hasPrefix("-") && !$0.hasSuffix("-") })
        else { return nil }
        return host
    }

    static func makeWebsiteURL(hostValue: String?, path: String) -> URL? {
        guard let websiteHost = validatedWebsiteHost(hostValue), path.hasPrefix("/") else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = websiteHost
        components.path = path
        return components.url
    }

    private static let configuredWebsiteHost = Bundle.main.object(
        forInfoDictionaryKey: "PinlyWebsiteHost"
    ) as? String

    static let websiteURL = makeWebsiteURL(hostValue: configuredWebsiteHost, path: "/")
    static let privacyPolicyURL = makeWebsiteURL(hostValue: configuredWebsiteHost, path: "/privacy/")
    static let termsOfUseURL = makeWebsiteURL(hostValue: configuredWebsiteHost, path: "/terms/")
    static let privacyChoicesURL = makeWebsiteURL(hostValue: configuredWebsiteHost, path: "/privacy-choices/")
    static let supportURL = makeWebsiteURL(hostValue: configuredWebsiteHost, path: "/support/")

    static func makeAppStoreURL(idValue raw: String?) -> URL? {
        guard let raw else { return nil }
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              id.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 })
        else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }

    static let appStoreURL = makeAppStoreURL(
        idValue: Bundle.main.object(forInfoDictionaryKey: "PinlyAppStoreID") as? String
    )
}
