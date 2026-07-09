import Foundation
import CoreLocation
@testable import Pinly

final class MockLocationProviding: LocationProviding {
    var userLocation: CLLocation?
    var currentDistrict: String = ""
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse

    var requestPermissionCallCount = 0
    var requestLocationCallCount = 0

    func requestPermission() {
        requestPermissionCallCount += 1
    }

    func requestLocation() {
        requestLocationCallCount += 1
    }
}
