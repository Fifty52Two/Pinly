import XCTest
import MapKit
import CoreLocation
@testable import Pinly

@MainActor
final class RouteManagerDeviationTests: XCTestCase {

    /// Eski implementasyon yalnızca polyline'ın köşe noktalarına bakıyordu; uzun düz
    /// bir segmentin ORTASINDAN 10 m yanda duran bir kullanıcı, iki uç noktaya da
    /// ~200 m uzaklıkta ölçülüp yanlışlıkla "rotadan saptı" sayılıyordu. Doğru davranış:
    /// nokta → doğru-parçası izdüşüm mesafesi, yani gerçek sapma (~10 m).
    func test_minimumDistanceToPolyline_midSegmentOffset_reportsPerpendicularDistanceNotEndpointDistance() {
        let manager = RouteManager()

        // ~419 m uzunluğunda düz bir segment (41.000°N boyunca 0.005° boylam farkı).
        let start = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.000)
        let end = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.005)
        var coords = [start, end]
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)

        // Segmentin tam ortasından enlemde ~10 m sapan bir konum.
        let midLongitude = (start.longitude + end.longitude) / 2
        let tenMetersInLatitude = 10.0 / 111_320.0
        let offCourse = CLLocationCoordinate2D(
            latitude: start.latitude + tenMetersInLatitude,
            longitude: midLongitude
        )

        let distance = manager.minimumDistanceToPolyline(polyline, from: offCourse)

        XCTAssertLessThan(distance, 30, "Segment ortasından 10m sapma, ~10m ölçülmeli — eski kod uç noktalara bakıp ~200m ölçüyordu")
    }

    func test_minimumDistanceToPolyline_pointExactlyOnSegment_isZero() {
        let manager = RouteManager()
        let start = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.000)
        let end = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.005)
        var coords = [start, end]
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)

        let onSegment = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.0025)
        let distance = manager.minimumDistanceToPolyline(polyline, from: onSegment)

        XCTAssertLessThan(distance, 1)
    }

    func test_minimumDistanceToPolyline_singlePointPolyline_fallsBackToPointDistance() {
        let manager = RouteManager()
        let point = CLLocationCoordinate2D(latitude: 41.000, longitude: 29.000)
        var coords = [point]
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)

        let nearby = CLLocationCoordinate2D(latitude: 41.001, longitude: 29.000)
        let distance = manager.minimumDistanceToPolyline(polyline, from: nearby)

        XCTAssertGreaterThan(distance, 0)
    }

    func test_minimumDistanceToPolyline_emptyPolyline_returnsInfinity() {
        let manager = RouteManager()
        var coords: [CLLocationCoordinate2D] = []
        let polyline = MKPolyline(coordinates: &coords, count: 0)

        let distance = manager.minimumDistanceToPolyline(polyline, from: CLLocationCoordinate2D(latitude: 41, longitude: 29))

        XCTAssertEqual(distance, .infinity)
    }
}
