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

// MARK: - NearbyResultBander

/// Yakınımda sonuçlarının 25'lik listeye indirgenme mantığı — saf fonksiyon, unit test edilir.
/// Basit "en yakın 25" yoğun bölgelerde yarıçapı anlamsız kılıyordu: kullanıcı 5 km seçse bile
/// merkeze en yakın 25 sonuç zaten ilk ~1 km içinde doluyordu, liste HİÇ değişmiyordu.
/// >1 km yarıçapta sonuçlar 3 eşit mesafe bandına ayrılıp round-robin ile karıştırılır —
/// böylece geniş yarıçap gerçekten daha uzak sonuçlar da getirir.
enum NearbyResultBander {
    static func diversify(_ places: [NearbyPlace], radius: Double) -> [NearbyPlace] {
        guard radius > 1000 else {
            return Array(places.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(25))
        }

        let band1Cutoff = radius / 3
        let band2Cutoff = radius * 2 / 3

        var bands: [[NearbyPlace]] = [[], [], []]
        for place in places {
            switch place.distanceMeters {
            case ..<band1Cutoff: bands[0].append(place)
            case ..<band2Cutoff: bands[1].append(place)
            default: bands[2].append(place)
            }
        }
        for i in bands.indices {
            bands[i].sort { $0.distanceMeters < $1.distanceMeters }
        }

        var result: [NearbyPlace] = []
        var cursors = [0, 0, 0]
        while result.count < 25 {
            var addedAny = false
            for b in bands.indices {
                guard cursors[b] < bands[b].count else { continue }
                result.append(bands[b][cursors[b]])
                cursors[b] += 1
                addedAny = true
                if result.count == 25 { break }
            }
            guard addedAny else { break }   // tüm bantlar tükendi — 25'ten az sonuç var
        }
        return result
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
            // MKLocalPointsOfInterestRequest dahili sonuç sınırı (~25) yüzünden yoğun
            // kategorilerde (restoran vb.) geniş yarıçap seçilse bile tüm sonuçlar
            // merkezin hemen çevresinden doluyordu — 5 km seçince bile 500 m ötesini
            // göremiyordun. Çözüm: >1 km yarıçapta aramayı merkez + 4 yönde kaydırılmış
            // noktalardan paralel yapıp sonuçları birleştirmek (spatial subdivision).
            if radiusMeters > 1000 {
                items = await searchPOIMultiCenter(
                    center: coordinate,
                    radius: radiusMeters,
                    poiCategories: poiCategories
                )
            } else {
                let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radiusMeters)
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: poiCategories)
                items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
            }
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category.localizedName
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radiusMeters * 2,
                longitudinalMeters: radiusMeters * 2
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
        return NearbyResultBander.diversify(places, radius: radiusMeters)
    }

    /// Geniş yarıçapta POI aramasını merkez + 4 yönde kaydırılmış noktalardan
    /// paralel yaparak Apple'ın dahili sonuç sınırını (~25) aşar. Tekilleştirme
    /// isim+koordinat ile yapılır.
    private func searchPOIMultiCenter(
        center: CLLocationCoordinate2D,
        radius: Double,
        poiCategories: [MKPointOfInterestCategory]
    ) async -> [MKMapItem] {
        let offset = radius * 0.5
        let latOffset = offset / 111_320
        let lonOffset = offset / (111_320 * cos(center.latitude * .pi / 180))

        let centers = [
            center,
            CLLocationCoordinate2D(latitude: center.latitude + latOffset, longitude: center.longitude),
            CLLocationCoordinate2D(latitude: center.latitude - latOffset, longitude: center.longitude),
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + lonOffset),
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude - lonOffset),
        ]

        let subRadius = radius * 0.6

        let allItems = await withTaskGroup(of: [MKMapItem].self) { group in
            for c in centers {
                group.addTask {
                    let request = MKLocalPointsOfInterestRequest(center: c, radius: subRadius)
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: poiCategories)
                    return (try? await MKLocalSearch(request: request).start().mapItems) ?? []
                }
            }
            var merged: [MKMapItem] = []
            for await batch in group { merged.append(contentsOf: batch) }
            return merged
        }

        // Tekilleştir: aynı isim + ~50m içindeki sonuçlar aynı mekan
        var seen: [(String, CLLocationCoordinate2D)] = []
        return allItems.filter { item in
            guard let name = item.name else { return false }
            let isDuplicate = seen.contains { existing in
                existing.0 == name &&
                CLLocation(latitude: existing.1.latitude, longitude: existing.1.longitude)
                    .distance(from: CLLocation(latitude: item.placemark.coordinate.latitude,
                                               longitude: item.placemark.coordinate.longitude)) < 50
            }
            if !isDuplicate {
                seen.append((name, item.placemark.coordinate))
            }
            return !isDuplicate
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
