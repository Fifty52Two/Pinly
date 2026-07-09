import Foundation

// MARK: - MapViewModel
//
// MapView'ın (top-level harita ekranı) iş mantığı: seçili/düzenlenen mekan
// durumu ve görünür mekan filtresi. `MainMapView`/`PlaceAnnotation`/`PlaceCard`
// saf UI bileşenleri olarak View dosyasında kalır.

@MainActor
final class MapViewModel: ObservableObject {
    @Published var selectedPlace: Place? = nil
    @Published var editingPlace: Place? = nil

    func visiblePlaces(_ places: [Place]) -> [Place] {
        places.filter { $0.coordinate != nil }
    }
}
