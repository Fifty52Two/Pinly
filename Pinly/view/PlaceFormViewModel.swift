import Foundation
import CoreLocation
import SwiftData

// MARK: - PlaceFormViewModel
//
// AddPlaceView + EditPlaceView'ın ortak form mantığı (isim/kategori/adres/not,
// mevcut konum kullanma, haritadan pinleme). İki ekran neredeyse aynı şekle
// sahip olduğu için (DRY) ortak base class'ta toplanır; kaydetme davranışı
// (yeni oluşturma vs güncelleme) alt sınıflarda farklılaşır.

@MainActor
class PlaceFormViewModel: ObservableObject {
    @Published var name: String
    @Published var category: String
    @Published var address: String
    @Published var notes: String
    @Published var isSaving = false
    @Published var usedCurrentLocation = false
    @Published var currentCoord: CLLocationCoordinate2D? = nil
    @Published var pinnedCoord: CLLocationCoordinate2D? = nil
    @Published var pinnedAddress = ""

    let geocoding: GeocodingProviding

    init(
        name: String = "",
        category: String = PlaceCategory.general.rawValue,
        address: String = "",
        notes: String = "",
        geocoding: GeocodingProviding = DefaultGeocodingService.shared
    ) {
        self.name = name
        self.category = category
        self.address = address
        self.notes = notes
        self.geocoding = geocoding
    }

    func fetchCurrentLocation(from location: LocationProviding) {
        guard let loc = location.userLocation else {
            location.requestLocation()
            return
        }
        currentCoord = loc.coordinate
        usedCurrentLocation = true
    }

    /// Adres elle değiştirilirse pinlenen konum geçersiz olur
    func handleAddressChanged() {
        if pinnedCoord != nil && address != pinnedAddress {
            pinnedCoord = nil
            pinnedAddress = ""
        }
    }

    func applyPinnedLocation(coord: CLLocationCoordinate2D, resolvedAddress: String) {
        pinnedCoord = coord
        pinnedAddress = resolvedAddress
        address = resolvedAddress
    }
}
