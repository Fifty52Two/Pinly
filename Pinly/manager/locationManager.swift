import Foundation
import CoreLocation

// MARK: - LocationProviding

/// Konum izni + tek seferlik konum/adres edinimi.
protocol LocationProviding: AnyObject {
    var userLocation: CLLocation? { get }
    var currentDistrict: String { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestPermission()
    func requestLocation()
}

// MARK: - NavigationLocationTracking

/// Navigasyon sırasında yüksek hassasiyetli sürekli konum takibi.
protocol NavigationLocationTracking: AnyObject {
    func startNavigationTracking()
    func stopNavigationTracking()
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, LocationProviding, NavigationLocationTracking {
    private let manager = CLLocationManager()
    private let geocoding: GeocodingProviding

    @Published var userLocation: CLLocation?
    @Published var currentDistrict: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var isNavigationTracking = false
    private var navigationTimer: Timer?

    init(geocoding: GeocodingProviding = DefaultGeocodingService.shared) {
        self.geocoding = geocoding
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    /// İzin istemi onboarding bittikten sonra PermissionView'den tetiklenir —
    /// init'te istemek sistem diyaloğunu onboarding'in üstüne düşürüyordu.
    func requestPermission() {
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
        Task { @MainActor in
            guard let placemark = await geocoding.reverseGeocode(coordinate: location.coordinate) else { return }
            currentDistrict = placemark.subLocality
                ?? placemark.subAdministrativeArea
                ?? placemark.locality
                ?? ""
        }
    }
}
