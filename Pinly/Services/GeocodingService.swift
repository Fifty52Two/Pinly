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
    let distanceMeters: Double

    var formattedDistance: String {
        distanceMeters < 1000
            ? "\(Int(distanceMeters)) m"
            : String(format: "%.1f km", distanceMeters / 1000)
    }
}

protocol NearbySearching {
    func searchNearby(
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory,
        radiusMeters: Double
    ) async -> [NearbyPlace]
}

// MARK: - NearbyCategoryResolver

/// Yakınımda aramasının kategori mantığı — saf fonksiyonlar, unit test edilir.
/// Metin sorgusu adında "park" geçen restoranı da döndürdüğü için sonuçlar
/// MapKit'in gerçek `pointOfInterestCategory` alanıyla doğrulanır; körlemesine
/// seçili kategoriyle damgalanmaz.
enum NearbyCategoryResolver {
    /// POI karşılığı olan kategoriler filtreli aranır (metin eşleşmesi devre dışı).
    /// `historical`/`general` için iOS 17'de POI kategorisi yok → metin sorgusuna düşer.
    static func poiCategories(for category: PlaceCategory) -> [MKPointOfInterestCategory]? {
        switch category {
        case .restaurant: return [.restaurant]
        case .cafe:       return [.cafe]
        case .park:       return [.park, .nationalPark]
        case .museum:     return [.museum]
        case .library:    return [.library]
        case .dessert:    return [.bakery]
        case .historical, .general: return nil
        }
    }

    static func placeCategory(from poi: MKPointOfInterestCategory?) -> PlaceCategory? {
        switch poi {
        case .restaurant:          return .restaurant
        case .cafe:                return .cafe
        case .bakery:              return .dessert
        case .park, .nationalPark: return .park
        case .museum:              return .museum
        case .library:             return .library
        default:                   return nil
        }
    }

    /// Sonucun gösterileceği kategori; `nil` dönerse sonuç listeden elenir.
    static func resolvedCategory(
        requested: PlaceCategory,
        poi: MKPointOfInterestCategory?
    ) -> PlaceCategory? {
        let mapped = placeCategory(from: poi)
        switch requested {
        case .historical:
            // Metin araması: MapKit sonucu somut başka bir kategori olarak
            // tanıyorsa ("Tarihi X Restoranı" → restaurant) tarihi yerden ele.
            return mapped == nil ? .historical : nil
        case .general:
            // Genel bir catch-all: sonucu atma, gerçek kategorisiyle göster.
            return mapped ?? .general
        default:
            // POI filtreli arama zaten garanti eder; bilinen kategori varsa
            // ondan türet (bakery → dessert gibi).
            return mapped ?? requested
        }
    }
}

final class DefaultNearbySearchService: NearbySearching {
    static let shared = DefaultNearbySearchService()

    func searchNearby(
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory,
        radiusMeters: Double
    ) async -> [NearbyPlace] {
        let items: [MKMapItem]
        if let poiCategories = NearbyCategoryResolver.poiCategories(for: category) {
            // Kategori bazlı POI araması — metin eşleşmesi yok, yanlış kategori giremez.
            let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radiusMeters)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: poiCategories)
            items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        } else {
            // POI karşılığı olmayan kategoriler (tarihi yer, genel) metinle aranır,
            // sonuçlar resolvedCategory ile ayıklanır.
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category.localizedName
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radiusMeters,
                longitudinalMeters: radiusMeters
            )
            items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let places = items.compactMap { item -> NearbyPlace? in
            guard let name = item.name, !name.isEmpty else { return nil }
            guard let resolved = NearbyCategoryResolver.resolvedCategory(
                requested: category,
                poi: item.pointOfInterestCategory
            ) else { return nil }
            let itemCoordinate = item.placemark.coordinate
            let distance = origin.distance(
                from: CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude)
            )
            // Metin araması region'ı taşabilir — yarıçapı burada da uygula.
            guard distance <= radiusMeters else { return nil }
            let address = [
                item.placemark.thoroughfare,
                item.placemark.subLocality ?? item.placemark.locality
            ].compactMap { $0 }.joined(separator: ", ")
            return NearbyPlace(
                name: name,
                address: address,
                coordinate: itemCoordinate,
                category: resolved,
                distanceMeters: distance
            )
        }
        return Array(places.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(25))
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
