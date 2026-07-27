import SwiftUI
import MapKit
import SwiftData
import StoreKit

struct RouteSummaryView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissRouteFlow) var dismissRouteFlow
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.requestReview) private var requestReview

    @StateObject private var viewModel = RouteSummaryViewModel()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )
    @State private var showArrivalBanner = false
    @State private var showRatingSheet = false
    @State private var showCompletionOverlay = false
    @State private var noteSaved = false
    @State private var showSharePicker = false
    @State private var showGPXPaywall = false
    @State private var showPDFPaywall = false
    @State private var showSaveRouteSheet = false
    @State private var showSoftPaywall = false
    @State private var showShareFormatPicker = false
    @State private var isComposingMemoryCard = false

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
                if viewModel.isLoadingRoutes {
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

                // Koordinatsız durak uyarısı — hedefi bilinmediği için hiç planlanamadı
                if routeManager.unroutableStopCount > 0 {
                    Label(
                        NSLocalizedString("Bazı durakların konumu yok — rotaya dahil edilemedi.", comment: ""),
                        systemImage: "mappin.slash"
                    )
                    .font(.caption)
                    .foregroundColor(PinlyTheme.warning)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }

                // Hesaplanamayan segment uyarısı — eskiden sessizce yutulurdu
                if routeManager.failedLegCount > 0 {
                    Label(
                        NSLocalizedString("Bazı segmentler hesaplanamadı — mesafe ve süre eksik olabilir.", comment: ""),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(PinlyTheme.warning)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }

                // Sağlık izni reddi bilgisi — hata değil, açıklama
                if viewModel.healthKitDenied && routeManager.isNavigating {
                    Label(
                        NSLocalizedString("Adım verisi için Ayarlar'dan Sağlık iznine ihtiyaç var.", comment: ""),
                        systemImage: "heart.slash"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
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
                            let stopCircleColor: Color = {
                                if isCompleted { return PinlyTheme.routeCompleted }
                                if isCurrentStop || isNextAfterPause { return PinlyTheme.primary }
                                return PinlyTheme.primary.opacity(0.35)
                            }()

                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(stopCircleColor)
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
                                            .foregroundColor(PinlyTheme.success)
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
                                        .fill(isCompleted ? PinlyTheme.routeCompleted.opacity(0.4) : PinlyTheme.primary.opacity(0.3))
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
                ArrivalBannerView(placeName: viewModel.arrivedPlaceName)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .zIndex(10)
            }

            // Completion overlay
            if showCompletionOverlay {
                RouteCompletionOverlay(
                    totalDistance: routeManager.totalRouteDistance,
                    totalTimeSeconds: routeManager.totalRouteTime,
                    stepCount: viewModel.lastCompletionStepCount,
                    stopsVisited: routePlaces.filter { $0.isVisited }.count,
                    totalStops: routePlaces.count,
                    onShareMemory: { showShareFormatPicker = true }
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCompletionOverlay = false
                    }
                    // App Store istemi kutlama KAPANDIKTAN sonra — konfetinin
                    // üstüne sistem dialogu bindirilmez
                    reviewPrompt.recordRouteCompletion()
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    if reviewPrompt.shouldPromptForReview(currentVersion: version) {
                        reviewPrompt.markPrompted(version: version)
                        routeManager.reset()
                        dismissRouteFlow()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            requestReview()
                        }
                    } else if viewModel.consumeSoftPaywallOffer() {
                        // Değer anı: ilk rota TAMAMLANDIKTAN sonra tek seferlik soft paywall
                        // (specs/FAZ1_REVENUECAT_KARAR.md). Rota akışı henüz KAPATILMAZ —
                        // dismissRouteFlow() fullScreenCover'ı söker ve sökülen view'dan
                        // sheet sunulamaz; reset+dismiss paywall kapanınca (sheet onDismiss).
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            showSoftPaywall = true
                        }
                    } else {
                        routeManager.reset()
                        dismissRouteFlow()
                    }
                }
                .transition(.opacity)
                .zIndex(20)
            }

            // Anı kartı üretilirken (harita izi + render) küçük ilerleme göstergesi
            if isComposingMemoryCard {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(NSLocalizedString("Hikayen hazırlanıyor...", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.75)))
                .zIndex(30)
            }
        }
        .navigationTitle(routeManager.isNavigating ? NSLocalizedString("Navigasyon", comment: "") : NSLocalizedString("Rota Hazır", comment: ""))
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
            viewModel.stopNote = ""
            noteSaved = false
        }
        .onChange(of: routeManager.arrivedAtPlace) { _, arrived in
            guard let place = arrived else { return }
            // routeManager.currentWaypointIndex son durakta rotanın SONUNU gösterir
            // (bkz. RouteManager.handleWaypointArrival) — index'i place'in routePlaces
            // içindeki gerçek konumundan türetmek daha güvenilir.
            let stopIndex = routePlaces.firstIndex(where: { $0.id == place.id }) ?? routeManager.currentWaypointIndex
            viewModel.handleArrival(place: place, stopIndex: stopIndex, context: modelContext, placeStore: placeStore)
            HapticPlayer.stopArrival()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showArrivalBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showArrivalBanner = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRatingSheet = true
            }
            routeManager.arrivedAtPlace = nil
        }
        .onChange(of: routeManager.isRouteComplete) { _, isComplete in
            guard isComplete else { return }
            locationManager.stopNavigationTracking()
            Task {
                let newBadges = await viewModel.handleRouteCompletion(
                    routePlaces: routePlaces,
                    fallbackRouteName: routeManager.routeName,
                    totalDistance: routeManager.totalRouteDistance,
                    totalTime: routeManager.totalRouteTime,
                    context: modelContext,
                    placeStore: placeStore
                )
                placeStore.pendingBadges.append(contentsOf: newBadges)
            }
            HapticPlayer.impact(.medium)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                viewModel.showInterstitialThenProceed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCompletionOverlay = true
                    }
                }
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            if let place = viewModel.pendingRatingPlace {
                RatingSheetView(
                    place: place,
                    existingPhotoCount: viewModel.stopPhotos[viewModel.pendingRatingStopIndex]?.count ?? 0,
                    placeStore: placeStore,
                    modelContext: modelContext,
                    onPhotoPicked: { image, alsoSaveAsPlacePhoto in
                        viewModel.addMemoryPhoto(
                            image,
                            stopIndex: viewModel.pendingRatingStopIndex,
                            alsoSaveAsPlacePhoto: alsoSaveAsPlacePhoto,
                            place: place,
                            context: modelContext,
                            placeStore: placeStore
                        )
                    }
                ) {
                    showRatingSheet = false
                }
            }
        }
        .sheet(isPresented: $showSoftPaywall, onDismiss: {
            // Soft paywall akışın SON adımı: kapanınca (satın alma ya da "Şimdi Değil")
            // rota akışı da kapanır — kutlama kapanışında ertelenen reset+dismiss burada.
            routeManager.reset()
            dismissRouteFlow()
        }) {
            PaywallView(source: "first_route_completed") { showSoftPaywall = false }
        }
        .confirmationDialog(
            NSLocalizedString("Hikayeni Paylaş", comment: ""),
            isPresented: $showShareFormatPicker,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Hikaye (9:16)", comment: "")) {
                Task { await shareMemoryCard(format: .story) }
            }
            Button(NSLocalizedString("Gönderi (4:5)", comment: "")) {
                Task { await shareMemoryCard(format: .post) }
            }
            Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // Note-adding section when paused at a stop
                if routeManager.isPausedAtStop {
                    VStack(spacing: 6) {
                        if noteSaved {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(PinlyTheme.success)
                                Text(NSLocalizedString("Not kaydedildi", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(PinlyTheme.success)
                            }
                            .transition(.opacity)
                        } else {
                            HStack(spacing: 8) {
                                TextField(NSLocalizedString("Bu mekan için not ekle...", comment: ""), text: $viewModel.stopNote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(PinlyTheme.fillMuted)
                                    .cornerRadius(10)

                                Button {
                                    addNoteToCurrentStop()
                                } label: {
                                    Text(NSLocalizedString("Ekle", comment: ""))
                                        .fontWeight(.semibold)
                                        .foregroundColor(viewModel.stopNote.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : PinlyTheme.primary)
                                }
                                .disabled(viewModel.stopNote.trimmingCharacters(in: .whitespaces).isEmpty)
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
                        .background(PinlyTheme.danger)
                        .cornerRadius(14)
                    }
                } else {
                    Button {
                        viewModel.showInterstitialThenProceed { showSharePicker = true }
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
                            name: $viewModel.shareRouteName,
                            category: $viewModel.shareRouteCategory,
                            onShare: {
                                let newBadges = viewModel.recordRouteShared(placeStore: placeStore)
                                placeStore.pendingBadges.append(contentsOf: newBadges)
                            }
                        )
                        .presentationDetents([.medium, .large])
                    }

                    Button {
                        viewModel.saveRouteName = viewModel.exportRouteName(fallbackRouteName: routeManager.routeName)
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
                            routeName: $viewModel.saveRouteName,
                            routeCategory: $viewModel.shareRouteCategory,
                            places: routePlaces,
                            onSave: { name, category in
                                let newBadges = viewModel.saveRoute(
                                    name: name,
                                    category: category,
                                    places: routePlaces,
                                    context: modelContext,
                                    placeStore: placeStore
                                )
                                placeStore.pendingBadges.append(contentsOf: newBadges)
                                showSaveRouteSheet = false
                                viewModel.saveRouteSuccess = true
                            }
                        )
                        .presentationDetents([.medium])
                    }
                    .alert(NSLocalizedString("Rota Kaydedildi!", comment: ""), isPresented: $viewModel.saveRouteSuccess) {
                        Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
                    } message: {
                        Text(String(format: NSLocalizedString("\"%@\" kayıtlı rotalarına eklendi.", comment: ""), viewModel.saveRouteName))
                    }

                    if routeManager.routePlaces.count >= 3 {
                        Button {
                            let optimized = RouteOrderOptimizer.nearestNeighborOrder(
                                places: routeManager.routePlaces,
                                start: locationManager.userLocation?.coordinate
                            )
                            let changed = optimized.map(\.name) != routeManager.routePlaces.map(\.name)
                            routeManager.applyRouteOrder(optimized)
                            if changed { loadRoutes() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text(NSLocalizedString("Sırayı Optimize Et", comment: ""))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(PinlyTheme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PinlyTheme.gold.opacity(0.10))
                            .cornerRadius(14)
                        }
                    }

                    Button {
                        if viewModel.isPro {
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
                        if viewModel.isPro {
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
                        viewModel.routeStartDate = Date()
                        viewModel.recordRouteStarted()
                        HapticPlayer.routeStarted()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            routeManager.isNavigating = true
                            locationManager.startNavigationTracking()
                            routeManager.startLiveActivity()
                        }
                        Task { await viewModel.requestHealthKitAuthorization() }
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
        guard viewModel.addNoteToCurrentStop(
            routePlaces: routePlaces,
            currentWaypointIndex: routeManager.currentWaypointIndex,
            context: modelContext,
            placeStore: placeStore
        ) else { return }

        withAnimation(.spring(response: 0.3)) {
            noteSaved = true
        }
        HapticPlayer.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                noteSaved = false
            }
        }
    }

    private func sharePDF() {
        guard let url = viewModel.sharePDF(
            places: routePlaces,
            fallbackRouteName: routeManager.routeName,
            totalDistance: routeManager.totalRouteDistance
        ) else { return }
        presentShareSheet(for: url)
    }

    private func shareGPX() {
        guard let url = viewModel.shareGPX(places: routePlaces, fallbackRouteName: routeManager.routeName) else { return }
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

    /// "Hikayeni Paylaş" — canlı rota verisinden (routePlaces + routePolylines,
    /// hâlâ RouteManager'da bellekte) gerçek harita izi üretir, anı fotoğraflarıyla
    /// birlikte kartı oluşturup paylaşım sheet'ini açar. Interstitial paylaşım
    /// niyetinden ÖNCE kalır (overlay zaten tamamlanma sonrası reklam sonrası açılır),
    /// paylaşımın ortasına reklam GİRMEZ.
    @MainActor
    private func shareMemoryCard(format: MemoryShareFormat) async {
        isComposingMemoryCard = true
        let mapSnapshot = await RouteMemoryMapSnapshotter.makeSnapshot(
            places: routePlaces,
            polylines: routeManager.routePolylines
        )
        let image = viewModel.shareMemoryImage(
            format: format,
            routePlaces: routePlaces,
            fallbackRouteName: routeManager.routeName,
            totalDistance: routeManager.totalRouteDistance,
            totalTime: routeManager.totalRouteTime,
            mapSnapshot: mapSnapshot,
            placeStore: placeStore
        )
        isComposingMemoryCard = false
        presentShareSheet(items: [image])
    }

    private func loadRoutes() {
        viewModel.isLoadingRoutes = true
        routeManager.calculateRoutes(from: locationManager.userLocation?.coordinate) {
            viewModel.isLoadingRoutes = false
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
