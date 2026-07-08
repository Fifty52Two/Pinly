import SwiftUI

enum ThemeStyle: String {
    case slate = "slate"
    case farad = "farad"
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "pinly.theme"

    var themeKey: String {
        get { UserDefaults.standard.string(forKey: ThemeManager.key) ?? "slate" }
        set {
            UserDefaults.standard.set(newValue, forKey: ThemeManager.key)
            objectWillChange.send()
        }
    }

    var style: ThemeStyle { ThemeStyle(rawValue: themeKey) ?? .slate }
}
