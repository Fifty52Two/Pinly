import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocation?
    @Published var currentDistrict: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var isNavigationTracking = false
    private var navigationTimer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
    }

    // Tek seferlik konum al (pil dostu)
    func requestLocation() {
        manager.requestLocation()
    }

    func startNavigationTracking() {
        isNavigationTracking = true
        // kCLLocationAccuracyBest yerine NearestTenMeters — yürüyüş için yeterli, %30+ pil tasarrufu
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.startUpdatingLocation()

        // 2 saat sonra otomatik durdur (kullanıcı uygulamayı kapatıp unutursa)
        navigationTimer?.invalidate()
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 7200, repeats: false) { [weak self] _ in
            self?.stopNavigationTracking()
        }
    }

    func stopNavigationTracking() {
        isNavigationTracking = false
        navigationTimer?.invalidate()
        navigationTimer = nil
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.stopUpdatingLocation()
    }

    // MARK: - Delegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            // İzin alındığında tek seferlik konum al
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        if !isNavigationTracking {
            // Navigasyon yoksa durdur (requestLocation() zaten bir kez çağırır ama güvenlik için)
            manager.stopUpdatingLocation()
            reverseGeocode(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // requestLocation() hata verirse (örn. simülatörde) sessizce geç
        print("❌ Konum hatası: \(error.localizedDescription)")
    }

    // MARK: - Reverse Geocode

    private func reverseGeocode(location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            DispatchQueue.main.async {
                self?.currentDistrict = placemark.subLocality
                    ?? placemark.subAdministrativeArea
                    ?? placemark.locality
                    ?? ""
            }
        }
    }
}
