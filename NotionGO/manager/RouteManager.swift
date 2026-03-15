import Foundation
import MapKit
import CoreLocation

class RouteManager: ObservableObject {
    @Published var selectedCategories: [String] = []
    @Published var selectedPlaces: [String: Place] = [:]

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

    var routePlaces: [Place] {
        selectedCategories.compactMap { selectedPlaces[$0] }
    }

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        guard isNavigating, currentWaypointIndex < routePlaces.count else { return nil }
        return routePlaces[currentWaypointIndex].coordinate
    }

    func reset() {
        selectedCategories = []
        selectedPlaces = [:]
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

    // MARK: - Route Calculation

    func calculateRoutes(from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void) {
        var allCoords: [CLLocationCoordinate2D] = []

        if let userCoord = userLocation {
            allCoords.append(userCoord)
        }
        allCoords += routePlaces.compactMap { $0.coordinate }

        guard allCoords.count >= 2 else { completion(); return }

        let pairs = Array(zip(allCoords, allCoords.dropFirst()))
        let count = pairs.count
        let group = DispatchGroup()

        var orderedPolylines = [MKPolyline?](repeating: nil, count: count)
        var orderedSteps = [[MKRoute.Step]?](repeating: nil, count: count)
        var orderedDistances = [Double?](repeating: nil, count: count)
        var orderedTimes = [TimeInterval?](repeating: nil, count: count)

        for (i, (from, to)) in pairs.enumerated() {
            group.enter()
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            request.transportType = .walking

            MKDirections(request: request).calculate { response, _ in
                defer { group.leave() }
                if let route = response?.routes.first {
                    orderedPolylines[i] = route.polyline
                    orderedSteps[i] = route.steps
                    orderedDistances[i] = route.distance
                    orderedTimes[i] = route.expectedTravelTime
                }
            }
        }

        group.notify(queue: .main) {
            self.routePolylines = orderedPolylines.compactMap { $0 }
            self.stepsPerSegment = orderedSteps.compactMap { $0 }
            self.segmentDistances = orderedDistances.compactMap { $0 }
            self.totalRouteDistance = self.segmentDistances.reduce(0, +)
            self.totalRouteTime = orderedTimes.compactMap { $0 }.reduce(0, +)
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
            isRouteComplete = true
            isNavigating = false
            completionPercentage = 1.0
            currentInstruction = ""
            remainingDistance = ""
        } else if currentWaypointIndex < stepsPerSegment.count {
            let nextSteps = stepsPerSegment[currentWaypointIndex]
            if let first = nextSteps.first {
                currentInstruction = first.instructions
                let fmt = MKDistanceFormatter()
                remainingDistance = fmt.string(fromDistance: first.distance)
            }
            updateCompletionPercentage()
        }
    }

    // MARK: - Arrival Handling

    private func handleWaypointArrival(place: Place) {
        arrivedAtPlace = place

        let nextIndex = currentWaypointIndex + 1
        if nextIndex >= routePlaces.count {
            // Last stop — complete route automatically
            currentWaypointIndex = nextIndex
            isRouteComplete = true
            isNavigating = false
            completionPercentage = 1.0
            currentInstruction = ""
            remainingDistance = ""
        } else {
            // Intermediate stop — pause and wait for user to continue
            isPausedAtStop = true
            currentInstruction = ""
            remainingDistance = ""
        }
    }

    // MARK: - Route Deviation & Recalculation

    private func checkAndRecalculateIfNeeded(userLocation: CLLocation) {
        guard !isRecalculating else { return }
        guard currentWaypointIndex < routePolylines.count else { return }

        // Cooldown: no more than once per 10 seconds
        if let lastTime = lastRecalculationTime, Date().timeIntervalSince(lastTime) < 10 { return }

        let polyline = routePolylines[currentWaypointIndex]
        let minDist = minimumDistanceToPolyline(polyline, from: userLocation.coordinate)

        if minDist > 75 {
            recalculateCurrentSegment(from: userLocation)
        }
    }

    private func minimumDistanceToPolyline(_ polyline: MKPolyline, from coordinate: CLLocationCoordinate2D) -> Double {
        let userLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDist = Double.infinity
        let points = polyline.points()
        for i in 0..<polyline.pointCount {
            let loc = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
            minDist = min(minDist, userLoc.distance(from: loc))
        }
        return minDist
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

        MKDirections(request: request).calculate { [weak self] response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecalculating = false
                guard let route = response?.routes.first else { return }

                if self.currentWaypointIndex < self.routePolylines.count {
                    self.routePolylines[self.currentWaypointIndex] = route.polyline
                }
                if self.currentWaypointIndex < self.stepsPerSegment.count {
                    self.stepsPerSegment[self.currentWaypointIndex] = route.steps
                }
                if self.currentWaypointIndex < self.segmentDistances.count {
                    self.segmentDistances[self.currentWaypointIndex] = route.distance
                }
                self.currentSegmentStepIndex = 0
                if let firstStep = route.steps.first {
                    self.currentInstruction = firstStep.instructions
                    let fmt = MKDistanceFormatter()
                    self.remainingDistance = fmt.string(fromDistance: firstStep.distance)
                }
            }
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
