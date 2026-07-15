import SwiftUI
import SwiftData
import CoreLocation
import GoogleMobileAds

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements
    @Environment(\.badges) private var badges
    @Environment(\.routeURLCoding) private var routeURLCoding
    @Environment(\.notificationScheduling) private var notificationScheduling
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @EnvironmentObject var languageManager: LanguageManager

    @State private var pendingImport: PlaceImportData? = nil
    @State private var showImportSheet = false
    @State private var isImporting = false
    @State private var showDeepLinkPaywall = false
    @State private var pendingRouteImport: RouteImport? = nil
    @State private var showRouteImportSheet = false
    @AppStorage("pinly.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("pinly.hasSetupProfile") private var hasSetupProfile = false
    @AppStorage("pinly.appearance") private var appearance = "system"
    @State private var hasRequestedAdConsent = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    notificationScheduling.scheduleWeeklyNotification()
                }
            } else if !hasSetupProfile {
                ProfileSetupView {
                    hasSetupProfile = true
                }
            } else {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    PermissionView()
                        .onAppear { locationManager.requestPermission() }
                case .denied, .restricted:
                    LocationDeniedView()
                default:
                    HomeView()
                        .environmentObject(placeStore)
                        .environmentObject(locationManager)
                        .environmentObject(routeManager)
                        .environmentObject(languageManager)
                }
            }
        }
        .onAppear {
            placeStore.load(context: modelContext)
            applyAppearance(appearance)
            requestAdConsentIfNeeded()
        }
        .onChange(of: appearance) { _, newValue in
            applyAppearance(newValue)
        }
        .onOpenURL { url in
            if url.host == "navigation" {
                // Live Activity butonundan gelen deep link — navigasyon zaten aktif, sadece ön plana al
                // HomeView'deki fullScreenCover routeManager.isNavigating'i izliyor
            } else if let data = routeURLCoding.parse(url: url) {
                pendingImport = data
                showImportSheet = true
            } else if let routeImport = routeURLCoding.parseRouteFull(url: url) {
                pendingRouteImport = routeImport
                showRouteImportSheet = true
            }
        }
        .sheet(isPresented: $showImportSheet, onDismiss: { pendingImport = nil }) {
            if let data = pendingImport {
                ImportConfirmView(
                    data: data,
                    isSaving: $isImporting,
                    onConfirm: { importPendingPlace(data) },
                    onCancel: { showImportSheet = false }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showRouteImportSheet, onDismiss: { pendingRouteImport = nil }) {
            if let routeImport = pendingRouteImport {
                RouteImportView(
                    routeImport: routeImport,
                    onConfirm: { importRoute() },
                    onCancel: { showRouteImportSheet = false },
                    onSaveToSavedRoutes: { saveRouteToSavedRoutes(routeImport) }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showDeepLinkPaywall) {
            PaywallView { showDeepLinkPaywall = false }
        }
        .alert(NSLocalizedString("Hata", comment: ""), isPresented: Binding(
            get: { placeStore.lastError != nil },
            set: { if !$0 { placeStore.lastError = nil } }
        )) {
            Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) { placeStore.lastError = nil }
        } message: {
            Text(placeStore.lastError ?? "")
        }
        // Hata olmayan bilgilendirmeler (örn. geocode başarısız, mekan konumsuz kaydedildi)
        .alert(NSLocalizedString("Bilgi", comment: ""), isPresented: Binding(
            get: { placeStore.lastNotice != nil },
            set: { if !$0 { placeStore.lastNotice = nil } }
        )) {
            Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) { placeStore.lastNotice = nil }
        } message: {
            Text(placeStore.lastNotice ?? "")
        }
    }

    /// Görünüm tercihini pencere seviyesinde uygular — sheet'ler ve
    /// fullScreenCover'lar dahil her şey etkilenir
    private func applyAppearance(_ raw: String) {
        let style: UIUserInterfaceStyle = switch raw {
        case "light": .light
        case "dark":  .dark
        default:      .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }

    /// UMP rızası + ATT izni akışını başlatır, tamamlanınca (ve sadece
    /// `canRequestAds` ise) AdMob SDK'sını ve interstitial yüklemesini açar.
    /// Onboarding sırasında da, dönen kullanıcıda da tek seferlik çalışır.
    private func requestAdConsentIfNeeded() {
        guard !hasRequestedAdConsent else { return }
        hasRequestedAdConsent = true
        ConsentManager.shared.requestConsentAndTracking {
            guard ConsentManager.shared.canRequestAds else { return }
            MobileAds.shared.start { _ in }
            AdManager.shared.beginLoadingAds()
        }
    }

    private func importRoute() {
        guard let routeImport = pendingRouteImport else { return }
        guard entitlements.canAddPlace(
            currentCount: placeStore.places.count + routeImport.places.count - 1
        ) else {
            showRouteImportSheet = false
            showDeepLinkPaywall = true
            return
        }
        let toImport = routeImport.places
        showRouteImportSheet = false
        pendingRouteImport = nil
        Task {
            for data in toImport {
                await placeStore.importPlace(data, context: modelContext)
            }
        }
    }

    private func saveRouteToSavedRoutes(_ routeImport: RouteImport) {
        showRouteImportSheet = false
        pendingRouteImport = nil

        let name = routeImport.name ?? NSLocalizedString("İçe Aktarılan Rota", comment: "")
        let lats = routeImport.places.compactMap { $0.latitude }
        let lons = routeImport.places.compactMap { $0.longitude }
        let centerLat = lats.isEmpty ? 41.015137 : lats.reduce(0, +) / Double(lats.count)
        let centerLon = lons.isEmpty ? 28.979530 : lons.reduce(0, +) / Double(lons.count)

        let snapshots = routeImport.places.enumerated().map { index, p in
            SavedPlaceSnapshot(
                name: p.name,
                category: p.category,
                address: p.address,
                notes: p.notes,
                latitude: p.latitude ?? centerLat,
                longitude: p.longitude ?? centerLon,
                sortIndex: index
            )
        }

        let route = SavedRoute(
            name: name,
            categoryRaw: routeImport.category?.rawValue,
            centerLatitude: centerLat,
            centerLongitude: centerLon,
            snapshots: snapshots
        )
        modelContext.insert(route)
        try? modelContext.save()
        badges.recordSavedRoute()
        placeStore.refreshBadges()
    }

    private func importPendingPlace(_ data: PlaceImportData) {
        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else {
            showImportSheet = false
            showDeepLinkPaywall = true
            return
        }
        isImporting = true
        Task {
            await placeStore.importPlace(data, context: modelContext)
            await MainActor.run {
                isImporting = false
                showImportSheet = false
            }
        }
    }
}
