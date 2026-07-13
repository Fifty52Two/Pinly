import SwiftUI

enum ThemeStyle: String {
    case slate = "slate"
    case lavender = "lavender"
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "pinly.theme"

    var themeKey: String {
        get {
            // Eski "farad" değerinden migrasyon
            if UserDefaults.standard.string(forKey: ThemeManager.key) == "farad" {
                UserDefaults.standard.set(ThemeStyle.lavender.rawValue, forKey: ThemeManager.key)
            }
            return UserDefaults.standard.string(forKey: ThemeManager.key) ?? "slate"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ThemeManager.key)
            objectWillChange.send()
        }
    }

    var style: ThemeStyle { ThemeStyle(rawValue: themeKey) ?? .slate }
}
