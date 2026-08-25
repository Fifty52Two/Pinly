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
         analytics: AnalyticsTracking = RuntimeAnalyticsService.shared) {
        self.entitlements = entitlements
        self.analytics = analytics
    }

    func importPlace(_ data: PlaceImportData, placeStore: PlaceRepository, context: ModelContext) async {
        isSaving = true
        await placeStore.importPlace(data, context: context)
        isSaving = false
        analytics.track(.placeAdded(source: .qr))
    }
}
