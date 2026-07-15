import Foundation
import CoreLocation
import SwiftData

// MARK: - QuickAddViewModel
//
// QuickAddSheet'in iş mantığı: konum edinimi + reverse geocode + freemium
// kontrolü + kaydetme. Eski `DispatchQueue.main.asyncAfter(2s)` bekleme hack'i
// yerine konum gelir gelmez (veya zaman aşımında) devam eden yapılandırılmış
// bir polling `Task` kullanılır.

@MainActor
final class QuickAddViewModel: ObservableObject {
    @Published var name = ""
    @Published var category: PlaceCategory = .general
    @Published var address = ""
    @Published var isLocating = true

    private let geocoding: GeocodingProviding
    private let entitlements: EntitlementProviding
    private let badges: BadgeServicing
    private let analytics: AnalyticsTracking

    init(
        geocoding: GeocodingProviding = DefaultGeocodingService.shared,
        entitlements: EntitlementProviding = LocalEntitlementService.shared,
        badges: BadgeServicing = DefaultBadgeService.shared,
        analytics: AnalyticsTracking = NoOpAnalyticsService.shared
    ) {
        self.geocoding = geocoding
        self.entitlements = entitlements
        self.badges = badges
        self.analytics = analytics
    }

    /// Konum iznini/isteğini tetikler, en fazla ~3 saniye bekleyip (0.2s aralıklarla
    /// kontrol ederek) konum gelir gelmez reverse-geocode eder. İzin yoksa/gelmezse
    /// zaman aşımında `isLocating` false'a düşer, kullanıcı manuel devam edebilir.
    func observeLocation(_ location: LocationProviding) {
        location.requestLocation()
        Task {
            for _ in 0..<15 {
                if let loc = location.userLocation {
                    isLocating = false
                    await reverseGeocode(loc)
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            isLocating = false
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        guard let placemark = await geocoding.reverseGeocode(coordinate: location.coordinate) else { return }
        let parts = [placemark.name, placemark.subLocality, placemark.locality].compactMap { $0 }
        address = parts.joined(separator: ", ")
    }

    /// Freemium limiti aşılıyorsa false döner (çağıran taraf paywall göstermeli).
    /// Mekan adı boşsa (henüz yazılmamışsa) sessizce true döner — kaydetme yapılmaz.
    @discardableResult
    func save(placeStore: PlaceRepository, userLocation: CLLocation?, context: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else { return false }

        let place = Place(name: trimmed, category: category.rawValue, address: address)
        if let loc = userLocation {
            place.latitude = loc.coordinate.latitude
            place.longitude = loc.coordinate.longitude
            place.locationName = address
        }
        context.insert(place)
        placeStore.save(context: context)
        placeStore.load(context: context)

        let newBadges = badges.check(placeStore: placeStore)
        placeStore.pendingBadges.append(contentsOf: newBadges)
        analytics.track(.placeAdded(source: .quickAdd))
        return true
    }
}
