import SwiftUI
import MapKit
import SwiftData

struct RouteSummaryView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissRouteFlow) var dismissRouteFlow
    @Environment(\.entitlements) private var entitlements
    @Environment(\.badges) private var badgeService
    @Environment(\.ads) private var adService

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
    @State private var showSharePicker = false
    @State private var shareRouteName = ""
    @State private var shareRouteCategory: RouteCategory = .city
    @State private var showGPXPaywall = false
    @State private var showPDFPaywall = false
    @State private var routeStartDate: Date? = nil
    @State private var showSaveRouteSheet = false
    @State private var saveRouteName = ""
    @State private var saveRouteSuccess = false

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
                        Text(NSLocalizedString("Rota yeniden hesaplanıyor...", comment: ""))
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
                        Text(NSLocalizedString("Rota hesaplanıyor...", comment: ""))
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
                        Text(NSLocalizedString("Rotanız", comment: ""))
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
                                            isCurrentStop ? PinlyTheme.primary :
                                            isNextAfterPause ? PinlyTheme.primary :
                                            PinlyTheme.primary.opacity(0.35)
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
                                        Text(NSLocalizedString("Varıldı!", comment: ""))
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    } else if isCurrentStop {
                                        Text(NSLocalizedString("Mevcut durak", comment: ""))
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(PinlyTheme.primary)
                                    } else if isNextAfterPause {
                                        Text(NSLocalizedString("Sonraki durak", comment: ""))
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(PinlyTheme.primary)
                                    }
                                }
                                Spacer()

                                if isCurrentStop {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundColor(PinlyTheme.primary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                            if index < routePlaces.count - 1 {
                                HStack {
                                    Spacer().frame(width: 34)
                                    Rectangle()
                                        .fill(isCompleted ? Color.green.opacity(0.4) : PinlyTheme.primary.opacity(0.3))
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
                    totalStops: routePlaces.count,
                    onShareCard: { shareCompletionCard() }
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
        .navigationTitle(routeManager.isNavigating ? NSLocalizedString("Navigasyon", comment: "") : NSLocalizedString("Rota Hazır! 🎉", comment: ""))
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
            badgeService.recordRouteCompleted()
            let newBadges = badgeService.check(placeStore: placeStore)
            placeStore.pendingBadges.append(contentsOf: newBadges)
            // HealthKit + RouteHistory kayıt
            let startDate  = routeStartDate ?? Date()
            let endDate    = Date()
            let distance   = routeManager.totalRouteDistance
            let duration   = routeManager.totalRouteTime
            let name       = !routeManager.routeName.isEmpty ? routeManager.routeName
                           : !shareRouteName.isEmpty ? shareRouteName
                           : NSLocalizedString("Rota", comment: "")
            let placeNames = routePlaces.map(\.name)
            let catRaw     = shareRouteCategory.rawValue
            Task {
                let stats = await HealthKitManager.fetchRouteStats(from: startDate, to: endDate)
                await MainActor.run {
                    let history = RouteHistory(
                        routeName: name,
                        placeNames: placeNames,
                        totalDistanceMeters: distance,
                        durationSeconds: duration,
                        stepCount: stats.steps,
                        categoryRaw: catRaw
                    )
                    modelContext.insert(history)
                    try? modelContext.save()
                }
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                adService.showInterstitialIfNeeded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCompletionOverlay = true
                    }
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
                                Text(NSLocalizedString("Not kaydedildi", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity)
                        } else {
                            HStack(spacing: 8) {
                                TextField(NSLocalizedString("Bu mekan için not ekle...", comment: ""), text: $stopNote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)

                                Button {
                                    addNoteToCurrentStop()
                                } label: {
                                    Text(NSLocalizedString("Ekle", comment: ""))
                                        .fontWeight(.semibold)
                                        .foregroundColor(stopNote.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : PinlyTheme.primary)
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
                                Text(String(format: NSLocalizedString("Sonraki Durağa Git: %@", comment: ""), routePlaces[nextIdx].name))
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            } else {
                                Text(NSLocalizedString("Rotayı Tamamla", comment: ""))
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.primary)
                        .cornerRadius(14)
                    }
                } else if routeManager.isNavigating {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.isNavigating = false
                            locationManager.stopNavigationTracking()
                            routeManager.endLiveActivity()
                            zoomToRoute()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text(NSLocalizedString("Navigasyonu Durdur", comment: ""))
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
                        adService.showInterstitialIfNeeded { showSharePicker = true }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text(NSLocalizedString("Linki Paylaş", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(PinlyTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.primary.opacity(0.10))
                        .cornerRadius(14)
                    }
                    .sheet(isPresented: $showSharePicker) {
                        RouteSharePickerView(
                            routePlaces: routePlaces,
                            name: $shareRouteName,
                            category: $shareRouteCategory,
                            onShare: {
                                badgeService.recordRouteShared()
                                let newBadges = badgeService.check(placeStore: placeStore)
                                placeStore.pendingBadges.append(contentsOf: newBadges)
                            }
                        )
                        .presentationDetents([.medium])
                    }

                    Button {
                        saveRouteName = exportRouteName
                        showSaveRouteSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                            Text(NSLocalizedString("Rotayı Kaydet", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(PinlyTheme.slate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.slate.opacity(0.10))
                        .cornerRadius(14)
                    }
                    .sheet(isPresented: $showSaveRouteSheet) {
                        SaveRouteSheet(
                            routeName: $saveRouteName,
                            routeCategory: $shareRouteCategory,
                            places: routePlaces,
                            onSave: { name, category in
                                SavedRouteManager.save(
                                    name: name,
                                    categoryRaw: category.rawValue,
                                    places: routePlaces,
                                    context: modelContext
                                )
                                badgeService.recordSavedRoute()
                                let newBadges = badgeService.check(placeStore: placeStore)
                                placeStore.pendingBadges.append(contentsOf: newBadges)
                                showSaveRouteSheet = false
                                saveRouteSuccess = true
                            }
                        )
                        .presentationDetents([.medium])
                    }
                    .alert(NSLocalizedString("Rota Kaydedildi!", comment: ""), isPresented: $saveRouteSuccess) {
                        Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
                    } message: {
                        Text(String(format: NSLocalizedString("\"%@\" kayıtlı rotalarına eklendi.", comment: ""), saveRouteName))
                    }

                    Button {
                        if entitlements.isPro {
                            shareGPX()
                        } else {
                            showGPXPaywall = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                            Text(NSLocalizedString("GPX İndir", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(PinlyTheme.primaryWarm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.primaryWarm.opacity(0.10))
                        .cornerRadius(14)
                    }
                    .sheet(isPresented: $showGPXPaywall) {
                        PaywallView { showGPXPaywall = false }
                    }

                    Button {
                        if entitlements.isPro {
                            sharePDF()
                        } else {
                            showPDFPaywall = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.richtext")
                            Text(NSLocalizedString("PDF İndir", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(PinlyTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.accent.opacity(0.10))
                        .cornerRadius(14)
                    }
                    .sheet(isPresented: $showPDFPaywall) {
                        PaywallView { showPDFPaywall = false }
                    }

                    Button {
                        routeStartDate = Date()
                        badgeService.recordRouteStarted()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.isNavigating = true
                            locationManager.startNavigationTracking()
                            routeManager.startLiveActivity()
                        }
                        Task { await HealthKitManager.requestAuthorization() }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text(NSLocalizedString("Navigasyonu Başlat", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.primary)
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

    private var exportRouteName: String {
        if !shareRouteName.isEmpty { return shareRouteName }
        if !routeManager.routeName.isEmpty { return routeManager.routeName }
        return NSLocalizedString("Rota", comment: "")
    }

    private func sharePDF() {
        let distanceStr = routeManager.totalRouteDistance > 0
            ? String(format: "%.1f km", routeManager.totalRouteDistance / 1000)
            : ""
        guard let url = PlaceImporter.buildPDFFile(for: routePlaces, name: exportRouteName, totalDistance: distanceStr) else { return }
        presentShareSheet(for: url)
    }

    private func shareGPX() {
        guard let url = PlaceImporter.buildGPXFile(for: routePlaces, name: exportRouteName) else { return }
        presentShareSheet(for: url)
    }

    private func presentShareSheet(items: [Any]) {
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: \.isKeyWindow)?
            .rootViewController
        // Overlay açıkken sheet en üstteki VC'den sunulmalı
        var top = rootVC
        while let presented = top?.presentedViewController { top = presented }
        top?.present(av, animated: true)
    }

    private func presentShareSheet(for url: URL) {
        presentShareSheet(items: [url])
    }

    private func shareCompletionCard() {
        let fmt = MKDistanceFormatter()
        fmt.unitStyle = .abbreviated
        let durationFmt = DateComponentsFormatter()
        durationFmt.unitsStyle = .abbreviated
        durationFmt.allowedUnits = routeManager.totalRouteTime >= 3600 ? [.hour, .minute] : [.minute]

        guard let image = RouteShareCardView.makeImage(
            routeName: exportRouteName,
            distanceText: fmt.string(fromDistance: routeManager.totalRouteDistance),
            durationText: durationFmt.string(from: routeManager.totalRouteTime) ?? "",
            stops: routePlaces.map(\.name)
        ) else { return }

        badgeService.recordRouteShared()
        let newBadges = badgeService.check(placeStore: placeStore)
        placeStore.pendingBadges.append(contentsOf: newBadges)
        presentShareSheet(items: [image])
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
