import SwiftUI
import MapKit
import SwiftData

struct RouteSummaryView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    @AppStorage("appTheme") private var storedTheme = "light"

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

    private var t: ThemeColors { ThemeColors.make(storedTheme) }
    var routePlaces: [Place] { routeManager.routePlaces }

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Spacer()
                    Text(routeManager.isNavigating ? "NAVİGASYON" : "ROTA HAZIR")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(t.title)
                    Spacer()
                    Button {
                        locationManager.stopNavigationTracking()
                        routeManager.reset()
                        dismissRouteFlow()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(t.subtitle)
                            .padding(9)
                            .background(Circle().fill(t.card))
                            .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

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
                .frame(height: routeManager.isNavigating ? 260 : 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routeManager.isNavigating)

                // Navigation banner
                if routeManager.isNavigating && !routeManager.isPausedAtStop {
                    NavBanner(
                        instruction: routeManager.currentInstruction,
                        distance: routeManager.remainingDistance,
                        stopIndex: min(routeManager.currentWaypointIndex + 1, routePlaces.count),
                        totalStops: routePlaces.count,
                        completionPct: routeManager.completionPercentage,
                        t: t
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Recalculation
                if routeManager.isRecalculating {
                    HStack(spacing: 8) {
                        ProgressView().tint(t.primary).scaleEffect(0.7)
                        Text("Rota yeniden hesaplanıyor...")
                            .font(.system(size: 12))
                            .foregroundColor(t.subtitle)
                    }
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Loading
                if isLoadingRoutes {
                    HStack(spacing: 8) {
                        ProgressView().tint(t.primary)
                        Text("Rota hesaplanıyor...")
                            .font(.system(size: 12))
                            .foregroundColor(t.subtitle)
                    }
                    .padding(.vertical, 8)
                }

                // Route overview
                if !routeManager.isNavigating && routeManager.totalRouteDistance > 0 {
                    RouteOverviewPanel(
                        totalDistance: routeManager.totalRouteDistance,
                        totalTime: routeManager.totalRouteTime,
                        stopCount: routePlaces.count,
                        t: t
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Stop list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ROTANIZ")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(2)
                            .foregroundColor(t.subtitle.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        ForEach(Array(routePlaces.enumerated()), id: \.element.id) { index, place in
                            let isArrivedHere = routeManager.isPausedAtStop && index == routeManager.currentWaypointIndex
                            let isCompleted = index < routeManager.currentWaypointIndex || isArrivedHere
                            let isCurrentStop = routeManager.isNavigating && !routeManager.isPausedAtStop && index == routeManager.currentWaypointIndex
                            let isNextAfterPause = routeManager.isPausedAtStop && index == routeManager.currentWaypointIndex + 1

                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isCompleted   ? t.primary :
                                            isCurrentStop ? t.accent :
                                            isNextAfterPause ? t.accent :
                                            t.accent.opacity(0.35)
                                        )
                                        .frame(width: 30, height: 30)
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(t.buttonText)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(t.buttonText)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(isCompleted ? t.subtitle : t.title)
                                        .strikethrough(isCompleted, color: t.subtitle)
                                    Text(place.category)
                                        .font(.system(size: 11))
                                        .foregroundColor(t.subtitle.opacity(0.7))
                                    if isArrivedHere {
                                        Text("Varıldı!")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(t.primary)
                                    } else if isCurrentStop {
                                        Text("Mevcut durak")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(t.accent)
                                    } else if isNextAfterPause {
                                        Text("Sonraki durak")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(t.accent)
                                    }
                                }
                                Spacer()
                                if isCurrentStop {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(t.accent)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                            if index < routePlaces.count - 1 {
                                HStack {
                                    Spacer().frame(width: 34)
                                    Rectangle()
                                        .fill(isCompleted ? t.primary.opacity(0.35) : t.accent.opacity(0.25))
                                        .frame(width: 2, height: 14)
                                        .padding(.horizontal, 14)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.bottom, 140)
                }
            }

            // Arrival banner
            if showArrivalBanner {
                ArrivalBannerView(placeName: arrivedPlaceName, t: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 80)
                    .zIndex(10)
            }

            // Completion overlay
            if showCompletionOverlay {
                RouteCompletionOverlay(
                    totalDistance: routeManager.totalRouteDistance,
                    stopsVisited: routePlaces.filter { $0.isVisited }.count,
                    totalStops: routePlaces.count,
                    t: t
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showCompletionOverlay = false }
                    routeManager.reset()
                    dismissRouteFlow()
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .onAppear { zoomToRoute(); loadRoutes() }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            guard routeManager.isNavigating, let loc = newLocation else { return }
            routeManager.updateNavigation(userLocation: loc)
        }
        .onChange(of: routeManager.currentWaypointIndex) { _, _ in stopNote = ""; noteSaved = false }
        .onChange(of: routeManager.arrivedAtPlace) { _, arrived in
            guard let place = arrived else { return }
            place.isVisited = true
            place.visitCount += 1
            try? modelContext.save()
            placeStore.load(context: modelContext)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            arrivedPlaceName = place.name
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showArrivalBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showArrivalBanner = false }
            }
            pendingRatingPlace = place
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showRatingSheet = true }
            routeManager.arrivedAtPlace = nil
        }
        .onChange(of: routeManager.isRouteComplete) { _, isComplete in
            guard isComplete else { return }
            locationManager.stopNavigationTracking()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showCompletionOverlay = true }
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            if let place = pendingRatingPlace {
                RatingSheetView(place: place, modelContext: modelContext, t: t) { showRatingSheet = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            if routeManager.isPausedAtStop {
                VStack(spacing: 6) {
                    if noteSaved {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(t.primary)
                            Text("Not kaydedildi")
                                .font(.system(size: 13))
                                .foregroundColor(t.primary)
                        }
                        .transition(.opacity)
                    } else {
                        HStack(spacing: 8) {
                            TextField("Bu mekan için not ekle...", text: $stopNote)
                                .font(.system(size: 14))
                                .foregroundColor(t.title)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(t.inputBg))

                            Button {
                                addNoteToCurrentStop()
                            } label: {
                                Text("Ekle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(stopNote.trimmingCharacters(in: .whitespaces).isEmpty ? t.subtitle.opacity(0.4) : t.primary)
                            }
                            .disabled(stopNote.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .animation(.spring(response: 0.3), value: noteSaved)
            }

            if routeManager.isPausedAtStop {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { routeManager.resumeNavigation() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        let nextIdx = routeManager.currentWaypointIndex + 1
                        if nextIdx < routePlaces.count {
                            Text("Sonraki Durağa Git: \(routePlaces[nextIdx].name)")
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(1)
                        } else {
                            Text("Rotayı Tamamla").font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(t.buttonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(t.accent)
                    .clipShape(Capsule())
                    .shadow(color: t.accent.opacity(0.25), radius: 12, y: 6)
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
                        Text("Navigasyonu Durdur").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(t.destructive)
                    .clipShape(Capsule())
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
                        Text("Navigasyonu Başlat").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(t.buttonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(t.accent)
                    .clipShape(Capsule())
                    .shadow(color: t.accent.opacity(0.25), radius: 12, y: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .padding(.top, 10)
        .background(t.bg)
    }

    private func addNoteToCurrentStop() {
        let trimmed = stopNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, routeManager.isPausedAtStop,
              routeManager.currentWaypointIndex < routePlaces.count else { return }
        let place = routePlaces[routeManager.currentWaypointIndex]
        place.notes = place.notes.isEmpty ? trimmed : place.notes + "\n• \(trimmed)"
        try? modelContext.save()
        placeStore.load(context: modelContext)
        stopNote = ""
        withAnimation(.spring(response: 0.3)) { noteSaved = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) { noteSaved = false }
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
        if let userCoord = locationManager.userLocation?.coordinate { coords.append(userCoord) }
        coords += routePlaces.compactMap { $0.coordinate }
        guard !coords.isEmpty else { return }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        withAnimation {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(latitudeDelta: max(0.02, (maxLat - minLat) * 1.5), longitudeDelta: max(0.02, (maxLon - minLon) * 1.5))
            )
        }
    }
}

// MARK: - Navigation Banner

struct NavBanner: View {
    let instruction: String
    let distance: String
    let stopIndex: Int
    let totalStops: Int
    let completionPct: Double
    let t: ThemeColors

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(t.accent).frame(width: 44, height: 44)
                    Image(systemName: "arrow.turn.up.right").font(.system(size: 18)).foregroundColor(t.buttonText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Durak \(stopIndex) / \(totalStops)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(t.primary)
                    Text(instruction.isEmpty ? "Devam edin" : instruction)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(t.title)
                        .lineLimit(2)
                    if !distance.isEmpty {
                        Text(distance).font(.system(size: 11)).foregroundColor(t.subtitle)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(t.separator).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(t.accent)
                        .frame(width: geo.size.width * CGFloat(completionPct), height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionPct)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}

// MARK: - Arrival Banner

struct ArrivalBannerView: View {
    let placeName: String
    let t: ThemeColors

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(t.buttonText.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: "mappin.circle.fill").font(.system(size: 20)).foregroundColor(t.buttonText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Varıldı!").font(.system(size: 11)).foregroundColor(t.buttonText.opacity(0.8))
                Text(placeName).font(.system(size: 14, weight: .bold)).foregroundColor(t.buttonText)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(t.primary))
        .shadow(color: t.primary.opacity(0.4), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Route Overview Panel

struct RouteOverviewPanel: View {
    let totalDistance: Double
    let totalTime: TimeInterval
    let stopCount: Int
    let t: ThemeColors

    var formattedDistance: String {
        let f = MKDistanceFormatter(); f.unitStyle = .abbreviated
        return f.string(fromDistance: totalDistance)
    }
    var formattedTime: String {
        let minutes = Int(totalTime / 60)
        return minutes < 60 ? "\(minutes) dk" : "\(minutes / 60)s \(minutes % 60)dk"
    }

    var body: some View {
        HStack(spacing: 0) {
            RouteStatItem(value: formattedDistance, label: "Yürüyüş", icon: "figure.walk", t: t)
            Rectangle().fill(t.separator).frame(width: 1, height: 32)
            RouteStatItem(value: formattedTime, label: "Süre", icon: "clock", t: t)
            Rectangle().fill(t.separator).frame(width: 1, height: 32)
            RouteStatItem(value: "\(stopCount)", label: "Durak", icon: "mappin.circle.fill", t: t)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}

struct RouteStatItem: View {
    let value: String
    let label: String
    let icon: String
    let t: ThemeColors

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(t.primary)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(t.title)
            Text(label).font(.system(size: 10)).foregroundColor(t.subtitle)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rating Sheet

struct RatingSheetView: View {
    let place: Place
    let modelContext: ModelContext
    let t: ThemeColors
    let onDismiss: () -> Void

    @State private var selectedRating: Int = 0

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Nasıldı?")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1)
                    .foregroundColor(t.subtitle)
                Text(place.name)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(t.title)
                    .multilineTextAlignment(.center)

                HStack(spacing: 14) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selectedRating = star }
                        } label: {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(star <= selectedRating ? t.accent : t.subtitle.opacity(0.3))
                                .scaleEffect(star <= selectedRating ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedRating)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Button("Atla") { onDismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(t.subtitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(t.card).overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1)))

                    Button("Kaydet") {
                        if selectedRating > 0 { place.userRating = selectedRating; try? modelContext.save() }
                        onDismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(selectedRating > 0 ? t.buttonText : t.subtitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(selectedRating > 0 ? t.accent : t.inputBg))
                    .disabled(selectedRating == 0)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 36)
            .padding(.horizontal, 24)
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - Route Completion Overlay

struct RouteCompletionOverlay: View {
    let totalDistance: Double
    let stopsVisited: Int
    let totalStops: Int
    let t: ThemeColors
    let onDismiss: () -> Void

    var formattedDistance: String {
        let f = MKDistanceFormatter(); f.unitStyle = .full
        return f.string(fromDistance: totalDistance)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(t.accent.opacity(0.2)).frame(width: 80, height: 80)
                    Image(systemName: "flag.checkered").font(.system(size: 36)).foregroundColor(t.primary)
                }
                Text("Rota Tamamlandı!")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(t.title)

                VStack(spacing: 12) {
                    CompletionStatRow(icon: "figure.walk", label: "Toplam Mesafe", value: formattedDistance, t: t)
                    Rectangle().fill(t.separator).frame(height: 1)
                    CompletionStatRow(icon: "checkmark.circle.fill", label: "Ziyaret Edilen", value: "\(stopsVisited) / \(totalStops)", t: t)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(t.card).overlay(RoundedRectangle(cornerRadius: 16).stroke(t.cardBorder, lineWidth: 1)))

                Button { onDismiss() } label: {
                    Text("Haritaya Dön")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(t.buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(t.accent)
                        .clipShape(Capsule())
                        .shadow(color: t.accent.opacity(0.25), radius: 12, y: 6)
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24).fill(t.bg))
            .padding(.horizontal, 24)
        }
    }
}

struct CompletionStatRow: View {
    let icon: String
    let label: String
    let value: String
    let t: ThemeColors

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(t.primary).frame(width: 22)
            Text(label).font(.system(size: 13)).foregroundColor(t.subtitle)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(t.title)
        }
    }
}

// MARK: - Navigation Map View (UIViewRepresentable — kept as-is)

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
        let shouldTrack = isNavigating && !isPausedAtStop
        if shouldTrack {
            if map.userTrackingMode != .follow { map.setUserTrackingMode(.follow, animated: true) }
        } else {
            if map.userTrackingMode != .none { map.setUserTrackingMode(.none, animated: false) }
            map.setRegion(region, animated: true)
        }

        context.coordinator.completedSegmentCount = isPausedAtStop ? currentWaypointIndex + 1 : currentWaypointIndex

        map.removeOverlays(map.overlays)
        map.addOverlays(routePolylines)

        let toRemove = map.annotations.filter { $0 is RouteAnnotation || $0 is NextWaypointAnnotation }
        map.removeAnnotations(toRemove)

        for (index, place) in routePlaces.enumerated() {
            guard let coord = place.coordinate else { continue }
            if isNavigating && !isPausedAtStop && index == currentWaypointIndex { continue }
            map.addAnnotation(RouteAnnotation(coordinate: coord, title: place.name, index: index + 1))
        }

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
                renderer.strokeColor = overlayIndex < completedSegmentCount ? UIColor.systemGreen : UIColor.systemBlue
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
                scaleAnim.values = [0.5, 1.2, 1.0]; scaleAnim.keyTimes = [0, 0.7, 1.0]
                let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
                opacityAnim.values = [0.8, 0.3, 0.0]; opacityAnim.keyTimes = [0, 0.7, 1.0]
                let animGroup = CAAnimationGroup()
                animGroup.animations = [scaleAnim, opacityAnim]; animGroup.duration = 1.5; animGroup.repeatCount = .infinity
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
        self.coordinate = coordinate; self.title = title; self.index = index
    }
}

class NextWaypointAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String? = nil
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}
