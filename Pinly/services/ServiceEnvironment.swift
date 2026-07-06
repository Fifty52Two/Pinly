import SwiftUI

// MARK: - Servis Environment Key'leri
//
// Uygulama kökünde (PinlyApp) gerçek implementasyonlar inject edilir.
// Default value'lar da gerçek implementasyonlar olduğu için preview'lar
// ekstra kurulum gerektirmez; testte protokole uyan mock'lar inject edilir.

private struct EntitlementsKey: EnvironmentKey {
    static let defaultValue: EntitlementProviding = LocalEntitlementService.shared
}

private struct BadgesKey: EnvironmentKey {
    static let defaultValue: BadgeServicing = DefaultBadgeService.shared
}

private struct AdsKey: EnvironmentKey {
    static let defaultValue: AdPresenting = AdManager.shared
}

extension EnvironmentValues {
    var entitlements: EntitlementProviding {
        get { self[EntitlementsKey.self] }
        set { self[EntitlementsKey.self] = newValue }
    }

    var badges: BadgeServicing {
        get { self[BadgesKey.self] }
        set { self[BadgesKey.self] = newValue }
    }

    var ads: AdPresenting {
        get { self[AdsKey.self] }
        set { self[AdsKey.self] = newValue }
    }
}
