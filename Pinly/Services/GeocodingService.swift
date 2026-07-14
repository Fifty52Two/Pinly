import Foundation
import CoreLocation
import MapKit

// MARK: - GeocodingProviding

/// Adres ⇄ koordinat çözümlemesinin tek kaynağı (forward: MKLocalSearch,
/// reverse: CLGeocoder). `PlaceStore`, `LocationManager`, `MapPinPickerViewModel`,
/// `QuickAddViewModel` bu protokole `@Environment(\.geocoding)` üzerinden erişir.
protocol GeocodingProviding: AnyObject {
    /// Serbest metin sorgusundan (isim + adres) koordinat bulur.
    func forwardGeocode(query: String) async -> CLLocationCoordinate2D?
    /// Koordinattan placemark çözümler; adres formatlama çağıran tarafın sorumluluğudur.
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> CLPlacemark?
}

// MARK: - NearbySearching

struct NearbyPlace: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: PlaceCategory
}

protocol NearbySearching {
    func searchNearby(
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory,
        radiusMeters: Double
    ) async -> [NearbyPlace]
}

final class DefaultNearbySearchService: NearbySearching {
    static let shared = DefaultNearbySearchService()

    func searchNearby(
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory,
        radiusMeters: Double
    ) async -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.localizedName
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        return items.prefix(10).compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            let address = [
                item.placemark.thoroughfare,
                item.placemark.subLocality ?? item.placemark.locality
            ].compactMap { $0 }.joined(separator: ", ")
            return NearbyPlace(
                name: name,
                address: address,
                coordinate: item.placemark.coordinate,
                category: category
            )
        }
    }
}

// MARK: - DefaultGeocodingService

final class DefaultGeocodingService: GeocodingProviding {
    static let shared = DefaultGeocodingService()

    func forwardGeocode(query: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let item = try? await MKLocalSearch(request: request).start().mapItems.first
        return (item ?? nil)?.placemark.coordinate
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> CLPlacemark? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // Her çağrıda taze bir CLGeocoder — panning sırasında art arda gelen
        // isteklerin birbirini iptal etmesine gerek kalmadan, çağıran taraf
        // (örn. MapPinPickerViewModel) kendi Task'ını iptal ederek eskiyeni eler.
        return try? await CLGeocoder().reverseGeocodeLocation(location).first
    }
}
