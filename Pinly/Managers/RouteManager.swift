import Foundation
import MapKit
import CoreLocation
import ActivityKit

// MARK: - RouteCalculating

/// Yürüyüş rotası segment hesaplama (MKDirections tabanlı).
@MainActor
protocol RouteCalculating: AnyObject {
    var routePolylines: [MKPolyline] { get }
    var stepsPerSegment: [[MKRoute.Step]] { get }
    var segmentDistances: [Double] { get }
    var totalRouteDistance: Double { get }
    var totalRouteTime: TimeInterval { get }
    var isRecalculating: Bool { get }
    func calculateRoutes(from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void)
    func recalculateCurrentSegment(from userLocation: CLLocation)
}

// MARK: - RouteNavigationTracking

/// Rota seçimi + turn-by-turn navigasyon ilerleme durumu.
@MainActor
protocol RouteNavigationTracking: AnyObject {
    var selectedCategories: [String] { get set }
    var selectedPlaces: [String: Place] { get set }
    var routeName: String { get set }
    var isNavigating: Bool { get set }
    var isPausedAtStop: Bool { get }
    var currentWaypointIndex: Int { get }
    var currentInstruction: String { get }
    var remainingDistance: String { get }
    var arrivedAtPlace: Place? { get set }
    var isRouteComplete: Bool { get }
    var completionPercentage: Double { get }
    var routePlaces: [Place] { get }
    var nextWaypointCoordinate: CLLocationCoordinate2D? { get }
    func setRoute(places: [Place], name: String)
    func reset()
    func updateNavigation(userLocation: CLLocation)
    func resumeNavigation()
}

// MARK: - RouteLiveActivityPresenting

/// Kilit ekranı Live Activity (ActivityKit) yönetimi.
@MainActor
protocol RouteLiveActivityPresenting: AnyObject {
    func startLiveActivity()
    func updateLiveActivity()
    func endLiveActivity()
}

// MARK: - RouteManager

@MainActor
class RouteManager: ObservableObject, RouteCalculating, RouteNavigationTracking, RouteLiveActivityPresenting {
    @Published var selectedCategories: [String] = []
    @Published var selectedPlaces: [String: Place] = [:]
    @Published var routeName: String = ""

    // Route data
    @Published var routePolylines: [MKPolyline] = []
    @Published var stepsPerSegment: [[MKRoute.Step]] = []
    @Published var segmentDistances: [Double] = []
    @Published var totalRouteDistance: Double = 0
    @Published var totalRouteTime: TimeInterval = 0

    // Navigation state
    @Published var isNavigating: Bool = false
    @Published var isPausedAtStop: Bool = false
    @Published var isRecalculating: Bool = false
    @Published var currentInstruction: String = ""
    @Published var remainingDistance: String = ""
    @Published var currentWaypointIndex: Int = 0
    @Published var currentSegmentStepIndex: Int = 0

    // Arrival / completion events
    @Published var arrivedAtPlace: Place? = nil
    @Published var isRouteComplete: Bool = false
    @Published var completionPercentage: Double = 0.0

    private var lastRecalculationTime: Date? = nil
    private var liveActivity: Activity<PinlyActivityAttributes>?

    var routePlaces: [Place] {
        selectedCategories.compactMap { selectedPlaces[$0] }
    }

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        guard isNavigating, currentWaypointIndex < routePlaces.count else { return nil }
        return routePlaces[currentWaypointIndex].coordinate
    }

    /// Rotayı doğrudan sıralı mekan listesiyle kurar (tek mekan navigasyonu,
    /// kayıtlı rota başlatma vb. — kategori seçim akışını atlayan çağıranlar için).
    func setRoute(places: [Place], name: String = "") {
        reset()
        var categories: [String] = []
        var dict: [String: Place] = [:]
        for (i, place) in places.enumerated() {
            let key = "\(i)_\(place.id.uuidString)"
            categories.append(key)
            dict[key] = place
        }
        selectedCategories = categories
        selectedPlaces = dict
        routeName = name
    }

    func reset() {
        endLiveActivity()
        selectedCategories = []
        selectedPlaces = [:]
        routeName = ""
        routePolylines = []
        stepsPerSegment = []
        segmentDistances = []
        totalRouteDistance = 0
        totalRouteTime = 0
        isNavigating = false
        isPausedAtStop = false
        isRecalculating = false
        currentInstruction = ""
        remainingDistance = ""
        currentWaypointIndex = 0
        currentSegmentStepIndex = 0
        arrivedAtPlace = nil
        isRouteComplete = false
        completionPercentage = 0
        lastRecalculationTime = nil
    }

    // MARK: - Live Activity

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard !routePlaces.isEmpty else { return }

        let nextPlace = currentWaypointIndex < routePlaces.count
            ? routePlaces[currentWaypointIndex].name : ""

        let state = PinlyActivityAttributes.ContentState(
            instruction: currentInstruction.isEmpty ? "Navigasyon başlıyor..." : currentInstruction,
            remainingDistance: remainingDistance,
            stopIndex: currentWaypointIndex + 1,
            totalStops: routePlaces.count,
            nextPlaceName: nextPlace,
            completionPercentage: completionPercentage
        )

        let title = routeName.isEmpty
            ? routePlaces.map(\.name).joined(separator: " → ")
            : routeName
        let attributes = PinlyActivityAttributes(routeName: title)

        liveActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let nextPlace = currentWaypointIndex < routePlaces.count
            ? routePlaces[currentWaypointIndex].name : ""

        let state = PinlyActivityAttributes.ContentState(
            instruction: currentInstruction,
            remainingDistance: remainingDistance,
            stopIndex: min(currentWaypointIndex + 1, routePlaces.count),
            totalStops: routePlaces.count,
            nextPlaceName: nextPlace,
            completionPercentage: completionPercentage
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task { await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate) }
        liveActivity = nil
    }

    // MARK: - Route Calculation

    func calculateRoutes(from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void) {
        var allCoords: [CLLocationCoordinate2D] = []

        if let userCoord = userLocation {
            allCoords.append(userCoord)
        }
        allCoords += routePlaces.compactMap { $0.coordinate }

        guard allCoords.count >= 2 else { completion(); return }

        let pairs = Array(zip(allCoords, allCoords.dropFirst()))

        Task {
            var orderedRoutes = [MKRoute?](repeating: nil, count: pairs.count)

            await withTaskGroup(of: (Int, MKRoute?).self) { group in
                for (i, (from, to)) in pairs.enumerated() {
                    group.addTask {
                        let request = MKDirections.Request()
                        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
                        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
                        request.transportType = .walking
                        let route = try? await MKDirections(request: request).calculate().routes.first
                        return (i, route)
                    }
                }
                for await (i, route) in group {
                    orderedRoutes[i] = route
                }
            }

            // Başarısız segmentler boş placeholder alır — indeksler routePlaces
            // ile hizalı kalmak zorunda, yoksa navigasyon yanlış durağa bağlanır.
            routePolylines = orderedRoutes.map { $0?.polyline ?? MKPolyline() }
            stepsPerSegment = orderedRoutes.map { $0?.steps ?? [] }
            segmentDistances = orderedRoutes.map { $0?.distance ?? 0 }
            totalRouteDistance = segmentDistances.reduce(0, +)
            totalRouteTime = orderedRoutes.compactMap { $0?.expectedTravelTime }.reduce(0, +)
            currentWaypointIndex = 0
            currentSegmentStepIndex = 0
            isRouteComplete = false
            completionPercentage = 0

            if let firstStep = stepsPerSegment.first?.first {
                currentInstruction = firstStep.instructions
                let fmt = MKDistanceFormatter()
                remainingDistance = fmt.string(fromDistance: firstStep.distance)
            }
            completion()
        }
    }

    // MARK: - Navigation Updates

    func updateNavigation(userLocation: CLLocation) {
        guard isNavigating else { return }
        guard !isPausedAtStop else { return }
        guard currentWaypointIndex < routePlaces.count else { return }

        // 1. Check 30m waypoint arrival
        let targetPlace = routePlaces[currentWaypointIndex]
        if let coord = targetPlace.coordinate {
            let targetLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if userLocation.distance(from: targetLocation) < 30 {
                handleWaypointArrival(place: targetPlace)
                return
            }
        }

        // 2. Check for route deviation and recalculate if needed
        checkAndRecalculateIfNeeded(userLocation: userLocation)

        // 3. Advance turn-by-turn step within current segment (20m threshold)
        guard currentWaypointIndex < stepsPerSegment.count else { return }
        let steps = stepsPerSegment[currentWaypointIndex]
        guard currentSegmentStepIndex < steps.count else { return }

        let step = steps[currentSegmentStepIndex]
        let stepLocation = CLLocation(
            latitude: step.polyline.coordinate.latitude,
            longitude: step.polyline.coordinate.longitude
        )
        if userLocation.distance(from: stepLocation) < 20 {
            currentSegmentStepIndex += 1
            if currentSegmentStepIndex < steps.count {
                currentInstruction = steps[currentSegmentStepIndex].instructions
                let fmt = MKDistanceFormatter()
                remainingDistance = fmt.string(fromDistance: steps[currentSegmentStepIndex].distance)
                updateLiveActivity()
            }
        }

        updateCompletionPercentage()
    }

    // MARK: - Manual Stop Advancement

    func resumeNavigation() {
        guard isPausedAtStop else { return }
        isPausedAtStop = false
        currentWaypointIndex += 1
        currentSegmentStepIndex = 0

        if currentWaypointIndex >= routePlaces.count {
            completeRoute()
        } else {
            if currentWaypointIndex < stepsPerSegment.count,
               let first = stepsPerSegment[currentWaypointIndex].first {
                currentInstruction = first.instructions
                let fmt = MKDistanceFormatter()
                remainingDistance = fmt.string(fromDistance: first.distance)
            }
            updateCompletionPercentage()
            updateLiveActivity()
        }
    }

    // MARK: - Arrival Handling

    private func handleWaypointArrival(place: Place) {
        arrivedAtPlace = place

        let nextIndex = currentWaypointIndex + 1
        if nextIndex >= routePlaces.count {
            // Last stop — complete route automatically
            currentWaypointIndex = nextIndex
            completeRoute()
        } else {
            // Intermediate stop — pause and wait for user to continue
            isPausedAtStop = true
            currentInstruction = ""
            remainingDistance = ""
            updateLiveActivity()
        }
    }

    private func completeRoute() {
        isRouteComplete = true
        isNavigating = false
        isPausedAtStop = false
        completionPercentage = 1.0
        currentInstruction = ""
        remainingDistance = ""
        endLiveActivity()
    }

    // MARK: - Route Deviation & Recalculation

    private func checkAndRecalculateIfNeeded(userLocation: CLLocation) {
        guard !isRecalculating else { return }
        guard currentWaypointIndex < routePolylines.count else { return }

        // Cooldown: no more than once per 10 seconds
        if let lastTime = lastRecalculationTime, Date().timeIntervalSince(lastTime) < 10 { return }

        let polyline = routePolylines[currentWaypointIndex]
        guard polyline.pointCount > 0 else {
            // Segment hesaplanamamıştı (placeholder) — rotayı kullanıcı konumundan yeniden dene
            recalculateCurrentSegment(from: userLocation)
            return
        }
        let minDist = minimumDistanceToPolyline(polyline, from: userLocation.coordinate)

        if minDist > 75 {
            recalculateCurrentSegment(from: userLocation)
        }
    }

    // internal (private değil) — RouteManagerDeviationTests'ten @testable erişim için.
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

    /// p noktasının [a,b] doğru parçasına dik izdüşüm mesafesi (metre).
    private func distance(from p: MKMapPoint, toSegment a: MKMapPoint, _ b: MKMapPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projection = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
        return p.distance(to: projection)
    }

    func recalculateCurrentSegment(from userLocation: CLLocation) {
        guard !isRecalculating else { return }
        guard currentWaypointIndex < routePlaces.count else { return }
        guard let targetCoord = routePlaces[currentWaypointIndex].coordinate else { return }

        isRecalculating = true
        lastRecalculationTime = Date()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: targetCoord))
        request.transportType = .walking

        Task {
            let route = try? await MKDirections(request: request).calculate().routes.first
            isRecalculating = false
            guard let route else { return }

            if currentWaypointIndex < routePolylines.count {
                routePolylines[currentWaypointIndex] = route.polyline
            }
            if currentWaypointIndex < stepsPerSegment.count {
                stepsPerSegment[currentWaypointIndex] = route.steps
            }
            if currentWaypointIndex < segmentDistances.count {
                segmentDistances[currentWaypointIndex] = route.distance
                totalRouteDistance = segmentDistances.reduce(0, +)
            }
            currentSegmentStepIndex = 0
            if let firstStep = route.steps.first {
                currentInstruction = firstStep.instructions
                let fmt = MKDistanceFormatter()
                remainingDistance = fmt.string(fromDistance: firstStep.distance)
            }
            updateLiveActivity()
        }
    }

    // MARK: - Completion

    private func updateCompletionPercentage() {
        guard totalRouteDistance > 0 else { return }
        let completedDist = segmentDistances.prefix(currentWaypointIndex).reduce(0, +)
        let currentSegmentTotalSteps = Double(
            currentWaypointIndex < stepsPerSegment.count
                ? max(1, stepsPerSegment[currentWaypointIndex].count)
                : 1
        )
        let currentSegmentDist = currentWaypointIndex < segmentDistances.count
            ? segmentDistances[currentWaypointIndex]
            : 0
        let partialDist = (Double(currentSegmentStepIndex) / currentSegmentTotalSteps) * currentSegmentDist
        completionPercentage = min(1.0, (completedDist + partialDist) / totalRouteDistance)
    }
}
