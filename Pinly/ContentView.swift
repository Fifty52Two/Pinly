import SwiftUI
import SwiftData
import CoreLocation
import GoogleMobileAds

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.badges) private var badges
    @Environment(\.routeURLCoding) private var routeURLCoding
    @Environment(\.notificationScheduling) private var notificationScheduling
    @Environment(\.analytics) private var analytics
    @Environment(\.profile) private var profileService
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @EnvironmentObject var languageManager: LanguageManager

    @State private var pendingImport: PlaceImportData? = nil
    @State private var showImportSheet = false
    @State private var isImporting = false
    @State private var pendingRouteImport: RouteImport? = nil
    @State private var showRouteImportSheet = false
    @AppStorage("pinly.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("pinly.hasSetupProfile") private var hasSetupProfile = false
    @AppStorage("pinly.hasDeferredLocationPermission") private var hasDeferredLocationPermission = false
    @State private var hasRequestedAdConsent = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    // Bildirim izni artık burada İSTENMEZ — izin isteme anı değere bağlı,
                    // Haftalık Rapor ekranındaki CTA'dan istenir (FAZ 5.4)
                }
            } else if !hasSetupProfile {
                ProfileSetupView {
                    hasSetupProfile = true
                }
            } else {
                if locationManager.authorizationStatus == .notDetermined && !hasDeferredLocationPermission {
                    PermissionView(
                        onAllow: { locationManager.requestPermission() },
                        onSkip: { hasDeferredLocationPermission = true }
                    )
                } else {
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
            // Koyu mod tasarımı henüz tamamlanmadı — kullanıcı seçimi geçici olarak devre dışı,
            // uygulama sabit açık görünümde kalıyor (bkz. ProfileTab'daki "Görünüm" satırı kaldırıldı).
            applyAppearance("light")
            if hasSeenOnboarding && hasSetupProfile {
                requestAdConsentIfNeeded()
            }
        }
        .onChange(of: hasSetupProfile) { _, isComplete in
            if isComplete { requestAdConsentIfNeeded() }
        }
        .onOpenURL { url in
            if url.host == "navigation" {
                // Live Activity butonundan gelen deep link — navigasyon zaten aktif, sadece ön plana al
                // HomeView'deki fullScreenCover routeManager.isNavigating'i izliyor
            } else if url.host == "sharedroute" {
                // Ortak rota özelliği V2'de açılacak — derin bağlantı şimdilik yok sayılır.
                _ = url
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
        // Ortak rota düzenleyici (SharedRouteEditorView) V1'de sunulmuyor: `sharedroute`
        // deep link'i yukarıda yok sayıldığı için `sharedRouteId` hiç set edilmiyordu ve bu
        // cover ölüydü. Ayrıca o ekran `AppleAuthService` üzerinden hesap açıyor — V1'de
        // hesap silme akışı olmadığı için hiçbir hesap oluşturma yolu bırakılmadı
        // (App Store Guideline 5.1.1(v)). V1.1'de sosyal katmanla birlikte geri gelecek.
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
        let audience = AdAudiencePolicy.category(profile: profileService.load())
        ConsentManager.shared.requestConsentAndTracking(audience: audience) {
            guard ConsentManager.shared.canRequestAds else { return }
            MobileAds.shared.start { _ in }
            AdManager.shared.beginLoadingAds()
        }
    }

    private func importRoute() {
        guard let routeImport = pendingRouteImport else { return }
        let toImport = routeImport.places
        showRouteImportSheet = false
        pendingRouteImport = nil
        analytics.track(.placeAdded(source: .routeImport))
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
        isImporting = true
        analytics.track(.placeAdded(source: .deeplink))
        Task {
            await placeStore.importPlace(data, context: modelContext)
            await MainActor.run {
                isImporting = false
                showImportSheet = false
            }
        }
    }
}
