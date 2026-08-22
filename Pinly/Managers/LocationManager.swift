import Foundation
import CoreLocation

// MARK: - LocationProviding

/// Konum izni + tek seferlik konum/adres edinimi.
protocol LocationProviding: AnyObject {
    var userLocation: CLLocation? { get }
    var currentDistrict: String { get }
    /// Şehir düzeyinde adı (`placemark.locality`) — `currentDistrict`'in aksine önce
    /// district/subLocality'ye değil doğrudan şehre bakar. FAZ 4 "İlk 30 Saniye" akışında
    /// hazır rota kataloğunu şehre göre seçmek için kullanılır (`StarterCityMatcher`).
    var currentCity: String { get }
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
    @Published var currentCity: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var isNavigationTracking = false
    private var navigationTimer: Timer?
    /// Kullanıcı durduğunda accuracy'i düşürüp pil tasarrufu yapar.
    private var isAdaptiveReduced = false

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
        manager.activityType = .fitness          // Yürüyüş navigasyonu — iOS pil yönetimi buna göre optimize eder
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10              // 10 m hareket olmadan güncelleme gelmesin
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
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
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
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
            manager.stopUpdatingLocation()
            reverseGeocode(location: location)
        } else {
            // Adaptive accuracy: kullanıcı durduğunda (hız < 0.3 m/s ≈ hareketsiz)
            // accuracy'i düşür → GPS çipi daha az çalışır → pil tasarrufu.
            // Hareket başlayınca (hız > 0.5 m/s) tekrar yükselt.
            let speed = max(0, location.speed)
            if speed < 0.3 && !isAdaptiveReduced {
                isAdaptiveReduced = true
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.distanceFilter = 25
            } else if speed > 0.5 && isAdaptiveReduced {
                isAdaptiveReduced = false
                manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                manager.distanceFilter = 10
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // requestLocation() hata verirse (örn. simülatörde) sessizce geç
    }

    // MARK: - Reverse Geocode

    private func reverseGeocode(location: CLLocation) {
        Task { @MainActor in
            guard let placemark = await geocoding.reverseGeocode(coordinate: location.coordinate) else { return }
            currentDistrict = placemark.subLocality
                ?? placemark.subAdministrativeArea
                ?? placemark.locality
                ?? ""
            currentCity = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.subLocality
                ?? ""
        }
    }
}
