import Foundation
import MapKit
import CoreLocation

// MARK: - RouteNavigationTracking

/// Rota secimi + turn-by-turn navigasyon ilerleme durumu.
@MainActor
protocol RouteNavigationTracking: AnyObject {
    var selectedCategories: [String] { get set }
    var selectedPlaces: [String: [Place]] { get set }
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
    var breadcrumbPolyline: MKPolyline? { get }
    func setRoute(places: [Place], name: String)
    func reset()
    func updateNavigation(userLocation: CLLocation)
    func resumeNavigation()
}

// MARK: - RouteManager

/// Navigasyon state yoneticisi. Rota hesaplama sorumluluklari `RouteCalculator`'a
/// delege edilmistir (SRP — Single Responsibility Principle).
@MainActor
class RouteManager: ObservableObject, RouteNavigationTracking {
    @Published var selectedCategories: [String] = []
    @Published var selectedPlaces: [String: [Place]] = [:]
    @Published var routeName: String = ""

    // Hesaplama verileri — RouteCalculator'dan okunur/yazilir
    @Published var routePolylines: [MKPolyline] = []
    @Published var stepsPerSegment: [[MKRoute.Step]] = []
    @Published var segmentDistances: [Double] = []
    @Published var totalRouteDistance: Double = 0
    @Published var totalRouteTime: TimeInterval = 0

    // Breadcrumb trail
    @Published var breadcrumbPolyline: MKPolyline? = nil
    private(set) var breadcrumbLocations: [CLLocation] = []

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

    @Published var failedLegCount: Int = 0
    @Published var unroutableStopCount: Int = 0

    private var lastRecalculationTime: Date? = nil
    private let liveActivityController = RouteLiveActivityController()
    let calculator = RouteCalculator()

    @Published private(set) var routePlaces: [Place] = []

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        guard isNavigating, currentWaypointIndex < routePlaces.count else { return nil }
        return routePlaces[currentWaypointIndex].coordinate
    }

    func setRoute(places: [Place], name: String = "") {
        reset()
        routePlaces = places
        routeName = name
    }

    func commitCategorySelection() {
        routePlaces = selectedCategories.flatMap { selectedPlaces[$0] ?? [] }
    }

    func applyRouteOrder(_ ordered: [Place]) {
        guard !isNavigating, ordered.count == routePlaces.count else { return }
        routePlaces = ordered
    }

    func reset() {
        endLiveActivity()
        selectedCategories = []
        selectedPlaces = [:]
        routeName = ""
        routePlaces = []
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
        failedLegCount = 0
        unroutableStopCount = 0
        lastRecalculationTime = nil
        breadcrumbLocations.removeAll()
        breadcrumbPolyline = nil
        calculator.reset()
    }

    // MARK: - Live Activity

    private func makeLiveActivitySnapshot(stopIndex: Int) -> LiveActivitySnapshot {
        let nextPlace = currentWaypointIndex < routePlaces.count
            ? routePlaces[currentWaypointIndex].name : ""
        let title = routeName.isEmpty
            ? routePlaces.map(\.name).joined(separator: " \u{2192} ")
            : routeName
        return LiveActivitySnapshot(
            title: title,
            instruction: currentInstruction,
            remainingDistance: remainingDistance,
            stopIndex: stopIndex,
            totalStops: routePlaces.count,
            nextPlaceName: nextPlace,
            completionPercentage: completionPercentage
        )
    }

    func startLiveActivity() {
        liveActivityController.start(snapshot: makeLiveActivitySnapshot(stopIndex: currentWaypointIndex + 1))
    }

    func updateLiveActivity() {
        liveActivityController.update(snapshot: makeLiveActivitySnapshot(stopIndex: min(currentWaypointIndex + 1, routePlaces.count)))
    }

    func endLiveActivity() {
        liveActivityController.end()
    }

    // MARK: - Route Calculation (delegated to RouteCalculator)

    func calculateRoutes(from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void) {
        calculator.calculateRoutes(places: routePlaces, from: userLocation) { [weak self] in
            guard let self else { return }
            self.syncFromCalculator()
            self.currentWaypointIndex = 0
            self.currentSegmentStepIndex = 0
            self.isRouteComplete = false
            self.completionPercentage = 0

            if let firstStep = self.stepsPerSegment.first?.first {
                self.currentInstruction = firstStep.instructions
                let fmt = MKDistanceFormatter()
                self.remainingDistance = fmt.string(fromDistance: firstStep.distance)
            }
            completion()
        }
    }

    /// Calculator'dan hesaplama sonuclarini kendi @Published property'lerine esler.
    private func syncFromCalculator() {
        routePolylines = calculator.routePolylines
        stepsPerSegment = calculator.stepsPerSegment
        segmentDistances = calculator.segmentDistances
        totalRouteDistance = calculator.totalRouteDistance
        totalRouteTime = calculator.totalRouteTime
        failedLegCount = calculator.failedLegCount
        unroutableStopCount = calculator.unroutableStopCount
        isRecalculating = calculator.isRecalculating
    }

    // MARK: - Navigation Updates

    func updateNavigation(userLocation: CLLocation) {
        guard isNavigating else { return }
        guard !isPausedAtStop else { return }
        guard currentWaypointIndex < routePlaces.count else { return }

        // Record breadcrumb
        if userLocation.horizontalAccuracy >= 0 && userLocation.horizontalAccuracy < 50 {
            if let last = breadcrumbLocations.last {
                if userLocation.distance(from: last) >= 3.0 {
                    breadcrumbLocations.append(userLocation)
                    let coords = breadcrumbLocations.map(\.coordinate)
                    breadcrumbPolyline = MKPolyline(coordinates: coords, count: coords.count)
                }
            } else {
                breadcrumbLocations.append(userLocation)
                let coords = breadcrumbLocations.map(\.coordinate)
                breadcrumbPolyline = MKPolyline(coordinates: coords, count: coords.count)
            }
        }

        // 1. 30m waypoint arrival
        let targetPlace = routePlaces[currentWaypointIndex]
        if let coord = targetPlace.coordinate {
            let targetLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if userLocation.distance(from: targetLocation) < 30 {
                handleWaypointArrival(place: targetPlace)
                return
            }
        }

        // 2. Route deviation
        checkAndRecalculateIfNeeded(userLocation: userLocation)

        // 3. Advance turn-by-turn step (20m threshold)
        guard currentWaypointIndex < stepsPerSegment.count else { return }
        let steps = stepsPerSegment[currentWaypointIndex]
        guard currentSegmentStepIndex < steps.count else { return }

        let step = steps[currentSegmentStepIndex]
        let stepEnd = calculator.endCoordinate(of: step.polyline)
        let stepLocation = CLLocation(latitude: stepEnd.latitude, longitude: stepEnd.longitude)
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
            currentWaypointIndex = nextIndex
            completeRoute()
        } else {
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
        if let lastTime = lastRecalculationTime, Date().timeIntervalSince(lastTime) < 10 { return }

        guard currentWaypointIndex < routePolylines.count else {
            recalculateCurrentSegment(from: userLocation)
            return
        }

        let polyline = routePolylines[currentWaypointIndex]
        guard polyline.pointCount > 0 else {
            recalculateCurrentSegment(from: userLocation)
            return
        }
        let minDist = calculator.minimumDistanceToPolyline(polyline, from: userLocation.coordinate)

        if minDist > 75 {
            recalculateCurrentSegment(from: userLocation)
        }
    }

    // internal — RouteManagerDeviationTests'ten @testable erisim icin.
    func minimumDistanceToPolyline(_ polyline: MKPolyline, from coordinate: CLLocationCoordinate2D) -> Double {
        calculator.minimumDistanceToPolyline(polyline, from: coordinate)
    }

    func recalculateCurrentSegment(from userLocation: CLLocation) {
        guard !isRecalculating else { return }
        guard currentWaypointIndex < routePlaces.count else { return }
        guard let targetCoord = routePlaces[currentWaypointIndex].coordinate else { return }

        isRecalculating = true
        lastRecalculationTime = Date()

        calculator.recalculateSegment(from: userLocation, waypointIndex: currentWaypointIndex, targetCoordinate: targetCoord) { [weak self] in
            guard let self else { return }
            self.syncFromCalculator()
            self.isRecalculating = false
            self.currentSegmentStepIndex = 0
            if let firstStep = self.calculator.stepsPerSegment[safe: self.currentWaypointIndex]?.first {
                self.currentInstruction = firstStep.instructions
                let fmt = MKDistanceFormatter()
                self.remainingDistance = fmt.string(fromDistance: firstStep.distance)
            }
            self.updateLiveActivity()
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

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
