import Foundation
import SwiftData

// MARK: - QRScannerViewModel
//
// QR kod ile mekan içe aktarma akışının iş mantığı: freemium gate kontrolü +
// kaydetme orkestrasyonu. Kamera/izin durumu View'da kalır (UI/donanım konusu).

@MainActor
final class QRScannerViewModel: ObservableObject {
    @Published var importData: PlaceImportData? = nil
    @Published var isSaving = false

    private let entitlements: EntitlementProviding
    private let analytics: AnalyticsTracking

    init(entitlements: EntitlementProviding = LocalEntitlementService.shared,
         analytics: AnalyticsTracking = NoOpAnalyticsService.shared) {
        self.entitlements = entitlements
        self.analytics = analytics
    }

    /// Freemium limiti aşılıyorsa false döner (çağıran taraf paywall göstermeli).
    func importPlace(_ data: PlaceImportData, placeStore: PlaceRepository, context: ModelContext) async -> Bool {
        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else {
            return false
        }
        isSaving = true
        await placeStore.importPlace(data, context: context)
        isSaving = false
        analytics.track(.placeAdded(source: .qr))
        return true
    }
}
