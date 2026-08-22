import Foundation
import MapKit
import CoreLocation

// MARK: - RouteCalculating

/// Yuruyus rotasi segment hesaplama (MKDirections tabanli).
@MainActor
protocol RouteCalculating: AnyObject {
    var routePolylines: [MKPolyline] { get set }
    var stepsPerSegment: [[MKRoute.Step]] { get set }
    var segmentDistances: [Double] { get set }
    var totalRouteDistance: Double { get set }
    var totalRouteTime: TimeInterval { get set }
    var isRecalculating: Bool { get set }
    var failedLegCount: Int { get set }
    var unroutableStopCount: Int { get set }
    func calculateRoutes(places: [Place], from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void)
    func recalculateSegment(from userLocation: CLLocation, waypointIndex: Int, targetCoordinate: CLLocationCoordinate2D, onUpdate: @escaping () -> Void)
}

// MARK: - RouteCalculator

/// Rota hesaplama sorumluluklarini RouteManager'dan ayiran bagimsiz sinif.
/// MKDirections cagrilari, polyline mesafe hesabi, segment planlama burada.
@MainActor
final class RouteCalculator: ObservableObject, RouteCalculating {
    @Published var routePolylines: [MKPolyline] = []
    @Published var stepsPerSegment: [[MKRoute.Step]] = []
    @Published var segmentDistances: [Double] = []
    @Published var totalRouteDistance: Double = 0
    @Published var totalRouteTime: TimeInterval = 0
    @Published var isRecalculating: Bool = false
    @Published var failedLegCount: Int = 0
    @Published var unroutableStopCount: Int = 0

    func calculateRoutes(places: [Place], from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void) {
        let segmentPlan = RouteSegmentPlanner.plan(places: places, userLocation: userLocation)

        unroutableStopCount = places.filter { $0.coordinate == nil }.count

        guard segmentPlan.contains(where: { $0 != nil }) else { completion(); return }

        Task {
            var orderedRoutes = [MKRoute?](repeating: nil, count: segmentPlan.count)

            await withTaskGroup(of: (Int, MKRoute?).self) { group in
                for (i, leg) in segmentPlan.enumerated() {
                    guard let leg else { continue }
                    group.addTask {
                        let request = MKDirections.Request()
                        request.source = MKMapItem(placemark: MKPlacemark(coordinate: leg.from))
                        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: leg.to))
                        request.transportType = .walking
                        let route = try? await MKDirections(request: request).calculate().routes.first
                        return (i, route)
                    }
                }
                for await (i, route) in group {
                    orderedRoutes[i] = route
                }
            }

            failedLegCount = zip(segmentPlan, orderedRoutes).filter { plan, route in plan != nil && route == nil }.count

            routePolylines = orderedRoutes.map { $0?.polyline ?? MKPolyline() }
            stepsPerSegment = orderedRoutes.map { $0?.steps ?? [] }
            segmentDistances = orderedRoutes.map { $0?.distance ?? 0 }
            totalRouteDistance = segmentDistances.reduce(0, +)
            totalRouteTime = orderedRoutes.compactMap { $0?.expectedTravelTime }.reduce(0, +)
            completion()
        }
    }

    func recalculateSegment(
        from userLocation: CLLocation,
        waypointIndex: Int,
        targetCoordinate: CLLocationCoordinate2D,
        onUpdate: @escaping () -> Void
    ) {
        guard !isRecalculating else { return }

        isRecalculating = true

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: targetCoordinate))
        request.transportType = .walking

        Task {
            let route = try? await MKDirections(request: request).calculate().routes.first
            isRecalculating = false
            guard let route else { return }

            while routePolylines.count <= waypointIndex { routePolylines.append(MKPolyline()) }
            while stepsPerSegment.count <= waypointIndex { stepsPerSegment.append([]) }
            while segmentDistances.count <= waypointIndex { segmentDistances.append(0) }

            routePolylines[waypointIndex] = route.polyline
            stepsPerSegment[waypointIndex] = route.steps
            segmentDistances[waypointIndex] = route.distance
            totalRouteDistance = segmentDistances.reduce(0, +)
            onUpdate()
        }
    }

    func reset() {
        routePolylines = []
        stepsPerSegment = []
        segmentDistances = []
        totalRouteDistance = 0
        totalRouteTime = 0
        isRecalculating = false
        failedLegCount = 0
        unroutableStopCount = 0
    }

    // MARK: - Geometry Helpers

    /// Polyline'in son noktasi; bos polyline'da `coordinate` fallback'i.
    func endCoordinate(of polyline: MKPolyline) -> CLLocationCoordinate2D {
        let count = polyline.pointCount
        guard count > 0 else { return polyline.coordinate }
        return polyline.points()[count - 1].coordinate
    }

    /// Kullanicinin polyline'a en yakin mesafesi (metre).
    func minimumDistanceToPolyline(_ polyline: MKPolyline, from coordinate: CLLocationCoordinate2D) -> Double {
        let user = MKMapPoint(coordinate)
        let points = polyline.points()
        let count = polyline.pointCount
        guard count > 0 else { return .infinity }
        guard count > 1 else { return user.distance(to: points[0]) }

        var minDist = Double.infinity
        for i in 0..<(count - 1) {
            minDist = min(minDist, distance(from: user, toSegment: points[i], points[i + 1]))
        }
        return minDist
    }

    /// p noktasinin [a,b] dogru parcasina dik izdüsüm mesafesi (metre).
    private func distance(from p: MKMapPoint, toSegment a: MKMapPoint, _ b: MKMapPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projection = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
        return p.distance(to: projection)
    }
}
