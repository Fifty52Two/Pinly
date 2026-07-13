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
