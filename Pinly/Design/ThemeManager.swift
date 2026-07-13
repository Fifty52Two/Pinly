import SwiftUI

enum ThemeStyle: String {
    case slate = "slate"
    case lavender = "lavender"
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let key = "pinly.theme"

    @Published var themeKey: String {
        didSet { UserDefaults.standard.set(themeKey, forKey: Self.key) }
    }

    private init() {
        var stored = UserDefaults.standard.string(forKey: Self.key) ?? ThemeStyle.slate.rawValue
        if stored == "farad" { stored = ThemeStyle.lavender.rawValue }   // eski değer migrasyonu
        themeKey = stored
    }

    var style: ThemeStyle { ThemeStyle(rawValue: themeKey) ?? .slate }
}
