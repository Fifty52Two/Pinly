import Foundation

enum FreemiumManager {
    static let freeLimit = 20
    private static let proKey = "pinly.isPro"
    private static let legacyProKey = "notiongo.isPro"

    static var isPro: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: proKey) != nil {
                return defaults.bool(forKey: proKey)
            }

            let legacyValue = defaults.bool(forKey: legacyProKey)
            defaults.set(legacyValue, forKey: proKey)
            return legacyValue
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: proKey)
            defaults.removeObject(forKey: legacyProKey)
        }
    }

    static func canAddPlace(currentCount: Int) -> Bool {
        isPro || currentCount < freeLimit
    }
}
