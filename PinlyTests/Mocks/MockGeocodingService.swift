import Foundation
import CoreLocation
@testable import Pinly

final class MockGeocodingService: GeocodingProviding {
    var forwardResult: CLLocationCoordinate2D?
    var reverseResult: CLPlacemark?

    func forwardGeocode(query: String) async -> CLLocationCoordinate2D? {
        forwardResult
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> CLPlacemark? {
        reverseResult
    }
}
