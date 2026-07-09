import Foundation
import ObjectiveC

// MARK: - LanguagePreferenceStoring

/// Uygulama dili tercihinin okunması/değiştirilmesi.
protocol LanguagePreferenceStoring: AnyObject {
    var currentLanguage: String { get }
    func setLanguage(_ code: String)
}

// MARK: - LanguageManager

final class LanguageManager: ObservableObject, LanguagePreferenceStoring {
    @Published var currentLanguage: String
    @Published var refreshID = UUID()

    static let supported: [(code: String, name: String, flag: String)] = [
        ("tr", "Türkçe", "🇹🇷"),
        ("en", "English", "🇬🇧"),
        ("es", "Español", "🇪🇸"),
        ("de", "Deutsch", "🇩🇪"),
        ("ru", "Русский", "🇷🇺"),
    ]

    init() {
        let saved  = UserDefaults.standard.string(forKey: "pinly.appLanguage")
        let system = Locale.current.language.languageCode?.identifier ?? "tr"
        let lang   = saved ?? (Self.supported.map(\.code).contains(system) ? system : "tr")
        currentLanguage = lang
        Bundle.setLanguage(lang)
    }

    func setLanguage(_ code: String) {
        guard code != currentLanguage else { return }
        currentLanguage = code
        UserDefaults.standard.set(code, forKey: "pinly.appLanguage")
        Bundle.setLanguage(code)
        refreshID = UUID()
    }
}

// MARK: - Bundle Swizzle

private var languageBundleKey: UInt8 = 0

private class BundleEx: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        object_setClass(Bundle.main, BundleEx.self)
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return }
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
