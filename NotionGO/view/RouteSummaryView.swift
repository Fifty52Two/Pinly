import SwiftUI
import MapKit
import SwiftData

struct RouteSummaryView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )
    @State private var isLoadingRoutes = false
    @State private var showArrivalBanner = false
    @State private var arrivedPlaceName = ""
    @State private var showRatingSheet = false
    @State private var pendingRatingPlace: Place? = nil
    @State private var showCompletionOverlay = false
    @State private var stopNote = ""
    @State private var noteSaved = false

    var routePlaces: [Place] { routeManager.routePlaces }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {

                // Map
                NavigationMapView(
                    region: $region,
                    routePolylines: $routeManager.routePolylines,
                    routePlaces: routePlaces,
                    userLocation: locationManager.userLocation,
                    nextWaypointCoordinate: routeManager.nextWaypointCoordinate,
                    currentWaypointIndex: routeManager.currentWaypointIndex,
                    isNavigating: routeManager.isNavigating,
                    isPausedAtStop: routeManager.isPausedAtStop
                )
                .frame(height: routeManager.isNavigating ? 280 : 340)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routeManager.isNavigating)

                // Navigation banner
                if routeManager.isNavigating && !routeManager.isPausedAtStop {
                    NavigationBanner(
                        instruction: routeManager.currentInstruction,
                        distance: routeManager.remainingDistance,
                        stopIndex: min(routeManager.currentWaypointIndex + 1, routePlaces.count),
                        totalStops: routePlaces.count,
                        completionPct: routeManager.completionPercentage
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Recalculation indicator
                if routeManager.isRecalculating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Rota yeniden hesaplanıyor...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Loading indicator
                if isLoadingRoutes {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Rota hesaplanıyor...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Route overview (when not navigating)
                if !routeManager.isNavigating && routeManager.totalRouteDistance > 0 {
                    RouteOverviewPanel(
                        totalDistance: routeManager.totalRouteDistance,
                        totalTime: routeManager.totalRouteTime,
                        stopCount: routePlaces.count
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }

                // Stop list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rotanız")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 14)

                        ForEach(Array(routePlaces.enumerated()), id: \.element.id) { index, place in
                            let isArrivedHere = routeManager.isPausedAtStop && index == routeManager.currentWaypointIndex
                            let isCompleted = index < routeManager.currentWaypointIndex || isArrivedHere
                            let isCurrentStop = routeManager.isNavigating
                                && !routeManager.isPausedAtStop
                                && index == routeManager.currentWaypointIndex
                            let isNextAfterPause = routeManager.isPausedAtStop
                                && index == routeManager.currentWaypointIndex + 1

                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isCompleted ? Color.green :
                                            isCurrentStop ? Color.blue :
                                            isNextAfterPause ? Color.blue :
                                            Color.blue.opacity(0.4)
                                        )
                                        .frame(width: 30, height: 30)
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(isCompleted ? .secondary : .primary)
                                        .strikethrough(isCompleted)
                                    Text(place.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if isArrivedHere {
                                        Text("Varıldı!")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    } else if isCurrentStop {
                                        Text("Mevcut durak")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    } else if isNextAfterPause {
                                        Text("Sonraki durak")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                                Spacer()

                                if isCurrentStop {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                            if index < routePlaces.count - 1 {
                                HStack {
                                    Spacer().frame(width: 34)
                                    Rectangle()
                                        .fill(isCompleted ? Color.green.opacity(0.4) : Color.blue.opacity(0.3))
                                        .frame(width: 2, height: 16)
                                        .padding(.horizontal, 14)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }

            // Arrival banner overlay
            if showArrivalBanner {
                ArrivalBannerView(placeName: arrivedPlaceName)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .zIndex(10)
            }

            // Completion overlay
            if showCompletionOverlay {
                RouteCompletionOverlay(
                    totalDistance: routeManager.totalRouteDistance,
                    stopsVisited: routePlaces.filter { $0.isVisited }.count,
                    totalStops: routePlaces.count
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCompletionOverlay = false
                    }
                    routeManager.reset()
                    dismissRouteFlow()
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .navigationTitle(routeManager.isNavigating ? "Navigasyon" : "Rota Hazır! 🎉")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    locationManager.stopNavigationTracking()
                    routeManager.reset()
                    dismissRouteFlow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
        }
        .onAppear {
            zoomToRoute()
            loadRoutes()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            guard routeManager.isNavigating, let loc = newLocation else { return }
            routeManager.updateNavigation(userLocation: loc)
        }
        .onChange(of: routeManager.currentWaypointIndex) { _, _ in
            stopNote = ""
            noteSaved = false
        }
        .onChange(of: routeManager.arrivedAtPlace) { _, arrived in
            guard let place = arrived else { return }
            place.isVisited = true
            place.visitCount += 1
            try? modelContext.save()
            placeStore.load(context: modelContext)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            arrivedPlaceName = place.name
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showArrivalBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showArrivalBanner = false
                }
            }
            pendingRatingPlace = place
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRatingSheet = true
            }
            routeManager.arrivedAtPlace = nil
        }
        .onChange(of: routeManager.isRouteComplete) { _, isComplete in
            guard isComplete else { return }
            locationManager.stopNavigationTracking()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showCompletionOverlay = true
                }
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            if let place = pendingRatingPlace {
                RatingSheetView(place: place, modelContext: modelContext) {
                    showRatingSheet = false
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // Note-adding section when paused at a stop
                if routeManager.isPausedAtStop {
                    VStack(spacing: 6) {
                        if noteSaved {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Not kaydedildi")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity)
                        } else {
                            HStack(spacing: 8) {
                                TextField("Bu mekan için not ekle...", text: $stopNote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)

                                Button {
                                    addNoteToCurrentStop()
                                } label: {
                                    Text("Ekle")
                                        .fontWeight(.semibold)
                                        .foregroundColor(stopNote.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
                                }
                                .disabled(stopNote.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .animation(.spring(response: 0.3), value: noteSaved)
                }

                // "Next Stop" button shown when paused at an intermediate stop
                if routeManager.isPausedAtStop {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.resumeNavigation()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            let nextIdx = routeManager.currentWaypointIndex + 1
                            if nextIdx < routePlaces.count {
                                Text("Sonraki Durağa Git: \(routePlaces[nextIdx].name)")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            } else {
                                Text("Rotayı Tamamla")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(14)
                    }
                } else if routeManager.isNavigating {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.isNavigating = false
                            locationManager.stopNavigationTracking()
                            zoomToRoute()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Navigasyonu Durdur")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(14)
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.isNavigating = true
                            locationManager.startNavigationTracking()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Navigasyonu Başlat")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .padding(.top, 10)
            .background(.regularMaterial)
        }
    }

    private func addNoteToCurrentStop() {
        let trimmed = stopNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard routeManager.isPausedAtStop else { return }
        guard routeManager.currentWaypointIndex < routePlaces.count else { return }

        let place = routePlaces[routeManager.currentWaypointIndex]
        if place.notes.isEmpty {
            place.notes = trimmed
        } else {
            place.notes += "\n• \(trimmed)"
        }
        try? modelContext.save()
        placeStore.load(context: modelContext)
        stopNote = ""
        withAnimation(.spring(response: 0.3)) {
            noteSaved = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                noteSaved = false
            }
        }
    }

    private func loadRoutes() {
        isLoadingRoutes = true
        routeManager.calculateRoutes(from: locationManager.userLocation?.coordinate) {
            isLoadingRoutes = false
        }
    }

    private func zoomToRoute() {
        var coords: [CLLocationCoordinate2D] = []
        if let userCoord = locationManager.userLocation?.coordinate {
            coords.append(userCoord)
        }
        coords += routePlaces.compactMap { $0.coordinate }
        guard !coords.isEmpty else { return }

        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        withAnimation {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(0.02, (maxLat - minLat) * 1.5),
                    longitudeDelta: max(0.02, (maxLon - minLon) * 1.5)
                )
            )
        }
    }
}

// MARK: - Navigation Banner

struct NavigationBanner: View {
    let instruction: String
    let distance: String
    let stopIndex: Int
    let totalStops: Int
    let completionPct: Double

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Durak \(stopIndex) / \(totalStops)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text(instruction.isEmpty ? "Devam edin" : instruction)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    if !distance.isEmpty {
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(completionPct), height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionPct)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(.regularMaterial)
    }
}

// MARK: - Arrival Banner

struct ArrivalBannerView: View {
    let placeName: String

    var body: some View {
        HStack(spacing: 12) {
            Text("🎉")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Varıldı!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(placeName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green)
        )
        .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Route Overview Panel

struct RouteOverviewPanel: View {
    let totalDistance: Double
    let totalTime: TimeInterval
    let stopCount: Int

    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: totalDistance)
    }

    var formattedTime: String {
        let minutes = Int(totalTime / 60)
        if minutes < 60 { return "\(minutes) dk" }
        return "\(minutes / 60)s \(minutes % 60)dk"
    }

    var body: some View {
        HStack(spacing: 0) {
            RouteStatItem(value: formattedDistance, label: "Toplam Yürüyüş", icon: "figure.walk")
            Divider().frame(height: 32)
            RouteStatItem(value: formattedTime, label: "Tahmini Süre", icon: "clock")
            Divider().frame(height: 32)
            RouteStatItem(value: "\(stopCount)", label: "Durak", icon: "mappin.circle.fill")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
}

struct RouteStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rating Sheet

struct RatingSheetView: View {
    let place: Place
    let modelContext: ModelContext
    let onDismiss: () -> Void

    @State private var selectedRating: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Nasıldı?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= selectedRating ? .yellow : .secondary)
                            .scaleEffect(star <= selectedRating ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedRating)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                Button("Atla") {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Button("Kaydet") {
                    if selectedRating > 0 {
                        place.userRating = selectedRating
                        try? modelContext.save()
                    }
                    onDismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedRating > 0 ? Color.blue : Color.gray)
                .cornerRadius(12)
                .disabled(selectedRating == 0)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .presentationDetents([.height(300)])
    }
}

// MARK: - Route Completion Overlay

struct RouteCompletionOverlay: View {
    let totalDistance: Double
    let stopsVisited: Int
    let totalStops: Int
    let onDismiss: () -> Void

    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .full
        return formatter.string(fromDistance: totalDistance)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 64))
                Text("Rota Tamamlandı!")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 14) {
                    CompletionStatRow(icon: "figure.walk", label: "Toplam Mesafe", value: formattedDistance)
                    CompletionStatRow(icon: "checkmark.circle.fill", label: "Ziyaret Edilen", value: "\(stopsVisited) / \(totalStops)")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )

                Button {
                    onDismiss()
                } label: {
                    Text("Haritaya Dön")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 24)
        }
    }
}

struct CompletionStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Navigation Map View

struct NavigationMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var routePolylines: [MKPolyline]
    let routePlaces: [Place]
    let userLocation: CLLocation?
    let nextWaypointCoordinate: CLLocationCoordinate2D?
    let currentWaypointIndex: Int
    let isNavigating: Bool
    let isPausedAtStop: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Camera: follow user during active navigation, manual region otherwise
        let shouldTrack = isNavigating && !isPausedAtStop
        if shouldTrack {
            if map.userTrackingMode != .follow {
                map.setUserTrackingMode(.follow, animated: true)
            }
        } else {
            if map.userTrackingMode != .none {
                map.setUserTrackingMode(.none, animated: false)
            }
            map.setRegion(region, animated: true)
        }

        // Update completed segment coloring
        context.coordinator.completedSegmentCount = isPausedAtStop
            ? currentWaypointIndex + 1
            : currentWaypointIndex

        map.removeOverlays(map.overlays)
        map.addOverlays(routePolylines)

        // Remove route annotations
        let toRemove = map.annotations.filter { $0 is RouteAnnotation || $0 is NextWaypointAnnotation }
        map.removeAnnotations(toRemove)

        // Add numbered stop annotations (skip current active waypoint — use pulse)
        for (index, place) in routePlaces.enumerated() {
            guard let coord = place.coordinate else { continue }
            if isNavigating && !isPausedAtStop && index == currentWaypointIndex { continue }
            let annotation = RouteAnnotation(
                coordinate: coord,
                title: place.name,
                index: index + 1
            )
            map.addAnnotation(annotation)
        }

        // Add pulsing annotation for next waypoint (only when actively navigating)
        if isNavigating && !isPausedAtStop, let coord = nextWaypointCoordinate {
            let nextCoordChanged = context.coordinator.currentNextWaypointCoordinate.map {
                abs($0.latitude - coord.latitude) > 0.0001 || abs($0.longitude - coord.longitude) > 0.0001
            } ?? true
            if nextCoordChanged {
                context.coordinator.currentNextWaypointCoordinate = coord
                map.addAnnotation(NextWaypointAnnotation(coordinate: coord))
            }
        } else {
            context.coordinator.currentNextWaypointCoordinate = nil
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var completedSegmentCount: Int = 0
        var currentNextWaypointCoordinate: CLLocationCoordinate2D? = nil

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                let overlayIndex = mapView.overlays.firstIndex(where: { $0 === polyline }) ?? 0
                renderer.strokeColor = overlayIndex < completedSegmentCount
                    ? UIColor.systemGreen
                    : UIColor.systemBlue
                renderer.lineWidth = 5
                renderer.lineDashPattern = [8, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let _ = annotation as? NextWaypointAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "nextWaypoint")
                view.frame = CGRect(x: 0, y: 0, width: 48, height: 48)

                let centerDot = CALayer()
                centerDot.frame = CGRect(x: 18, y: 18, width: 12, height: 12)
                centerDot.cornerRadius = 6
                centerDot.backgroundColor = UIColor.systemBlue.cgColor
                view.layer.addSublayer(centerDot)

                let pulseRing = CALayer()
                pulseRing.frame = CGRect(x: 4, y: 4, width: 40, height: 40)
                pulseRing.cornerRadius = 20
                pulseRing.borderWidth = 3
                pulseRing.borderColor = UIColor.systemBlue.cgColor
                pulseRing.opacity = 0
                view.layer.addSublayer(pulseRing)

                let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnim.values = [0.5, 1.2, 1.0]
                scaleAnim.keyTimes = [0, 0.7, 1.0]

                let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
                opacityAnim.values = [0.8, 0.3, 0.0]
                opacityAnim.keyTimes = [0, 0.7, 1.0]

                let animGroup = CAAnimationGroup()
                animGroup.animations = [scaleAnim, opacityAnim]
                animGroup.duration = 1.5
                animGroup.repeatCount = .infinity
                pulseRing.add(animGroup, forKey: "pulse")

                return view
            }

            if let routeAnnotation = annotation as? RouteAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "route")
                view.glyphText = "\(routeAnnotation.index)"
                view.markerTintColor = .systemBlue
                view.titleVisibility = .visible
                return view
            }

            return nil
        }
    }
}

// MARK: - Annotations

class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let index: Int

    init(coordinate: CLLocationCoordinate2D, title: String, index: Int) {
        self.coordinate = coordinate
        self.title = title
        self.index = index
    }
}

class NextWaypointAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String? = nil

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
