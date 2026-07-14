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

private struct GeocodingKey: EnvironmentKey {
    static let defaultValue: GeocodingProviding = DefaultGeocodingService.shared
}

private struct HealthStatsKey: EnvironmentKey {
    static let defaultValue: HealthStatsProviding = HealthKitService.shared
}

private struct SavedRoutesKey: EnvironmentKey {
    static let defaultValue: SavedRouteRepository = DefaultSavedRouteRepository.shared
}

private struct RouteURLCodingKey: EnvironmentKey {
    static let defaultValue: RouteURLCoding = DefaultRouteURLCoder()
}

private struct SwarmImportingKey: EnvironmentKey {
    static let defaultValue: SwarmImporting = DefaultSwarmImporter()
}

private struct RouteExportingKey: EnvironmentKey {
    static let defaultValue: RouteExporting = DefaultRouteExporter()
}

private struct WeeklyStatsKey: EnvironmentKey {
    static let defaultValue: WeeklyStatsComputing = DefaultWeeklyStatsComputer()
}

private struct NotificationSchedulingKey: EnvironmentKey {
    static let defaultValue: NotificationScheduling = DefaultNotificationScheduler()
}

private struct QRCodeGeneratingKey: EnvironmentKey {
    static let defaultValue: QRCodeGenerating = DefaultQRCodeGenerator()
}

private struct ProfileKey: EnvironmentKey {
    static let defaultValue: ProfileProviding = DefaultProfileService.shared
}

private struct ReviewPromptKey: EnvironmentKey {
    static let defaultValue: ReviewPromptDeciding = DefaultReviewPromptService.shared
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

    var geocoding: GeocodingProviding {
        get { self[GeocodingKey.self] }
        set { self[GeocodingKey.self] = newValue }
    }

    var healthStats: HealthStatsProviding {
        get { self[HealthStatsKey.self] }
        set { self[HealthStatsKey.self] = newValue }
    }

    var savedRoutes: SavedRouteRepository {
        get { self[SavedRoutesKey.self] }
        set { self[SavedRoutesKey.self] = newValue }
    }

    var routeURLCoding: RouteURLCoding {
        get { self[RouteURLCodingKey.self] }
        set { self[RouteURLCodingKey.self] = newValue }
    }

    var swarmImporting: SwarmImporting {
        get { self[SwarmImportingKey.self] }
        set { self[SwarmImportingKey.self] = newValue }
    }

    var routeExporting: RouteExporting {
        get { self[RouteExportingKey.self] }
        set { self[RouteExportingKey.self] = newValue }
    }

    var weeklyStats: WeeklyStatsComputing {
        get { self[WeeklyStatsKey.self] }
        set { self[WeeklyStatsKey.self] = newValue }
    }

    var notificationScheduling: NotificationScheduling {
        get { self[NotificationSchedulingKey.self] }
        set { self[NotificationSchedulingKey.self] = newValue }
    }

    var qrCodeGenerator: QRCodeGenerating {
        get { self[QRCodeGeneratingKey.self] }
        set { self[QRCodeGeneratingKey.self] = newValue }
    }

    var profile: ProfileProviding {
        get { self[ProfileKey.self] }
        set { self[ProfileKey.self] = newValue }
    }

    var reviewPrompt: ReviewPromptDeciding {
        get { self[ReviewPromptKey.self] }
        set { self[ReviewPromptKey.self] = newValue }
    }
}
