import Foundation
import CoreLocation

// MARK: - MapPinPickerViewModel
//
// MapPinPickerView'ın reverse-geocode mantığı. Panning sırasında art arda
// gelen isteklerde eskisini `Task` iptaliyle eleriz — `CLGeocoder.cancelGeocode()`
// yerine Swift concurrency'nin doğal iptal mekanizması kullanılır.

@MainActor
final class MapPinPickerViewModel: ObservableObject {
    @Published var resolvedAddress = ""
    @Published var geocodeFailed = false
    @Published var isGeocoding = false

    private let geocoding: GeocodingProviding
    private var geocodeTask: Task<Void, Never>?

    init(geocoding: GeocodingProviding = DefaultGeocodingService.shared) {
        self.geocoding = geocoding
    }

    /// Sadece kamera durunca (.onEnd) çağrılmalı — doğal debounce.
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        isGeocoding = true
        geocodeFailed = false

        geocodeTask = Task {
            let placemark = await geocoding.reverseGeocode(coordinate: coordinate)
            guard !Task.isCancelled else { return }

            isGeocoding = false
            if let placemark, let formatted = Self.formatAddress(placemark) {
                resolvedAddress = formatted
                geocodeFailed = false
            } else {
                resolvedAddress = ""
                geocodeFailed = true
            }
        }
    }

    /// Adres çözümlenemezse koordinat metni kullan — adres alanı boş kalmasın
    func confirmAddress(for coordinate: CLLocationCoordinate2D) -> String {
        resolvedAddress.isEmpty
            ? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
            : resolvedAddress
    }

    /// Placemark'tan okunabilir adres üretir
    static func formatAddress(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                parts.append("\(thoroughfare) \(subThoroughfare)")
            } else {
                parts.append(thoroughfare)
            }
        } else if let name = placemark.name {
            parts.append(name)
        }
        if let subLocality = placemark.subLocality, !parts.contains(subLocality) {
            parts.append(subLocality)
        }
        if let locality = placemark.locality, !parts.contains(locality) {
            parts.append(locality)
        }
        if let adminArea = placemark.administrativeArea, !parts.contains(adminArea) {
            parts.append(adminArea)
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
