import SwiftUI
import SwiftData

// MARK: - Tab Bar Ana Yapısı

struct HomeView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.modelContext) private var modelContext

    // Test/otomasyon: -pinly.selectedTabOverride N ile başlangıç sekmesi seçilebilir
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "pinly.selectedTabOverride")
    @State private var showNavigationFromDeepLink = false
    @State private var showQuickAdd = false

    // FAZ 4 "İlk 30 Saniye": onboarding + konum izni sonrası, boş bir hesapla HomeView ilk
    // kez açıldığında bir KERELİK gösterilen hazır rota kurulum akışı. Konum izni burada
    // İSTENMEZ — ContentView bu ekrana yalnızca izin zaten verilmişken geçer (mimari kısıt).
    @AppStorage("pinly.firstRouteFlowShown") private var firstRouteFlowShown = false
    @State private var hasCheckedFirstRouteFlow = false
    @State private var showFirstRouteSetup = false
    @State private var pendingFirstRoute: SavedRoute? = nil
    @State private var showFirstRouteSummary = false

    private var tabItems: [PinlyTabItem] {
        [
            PinlyTabItem(icon: "house", title: NSLocalizedString("Ana", comment: "")),
            PinlyTabItem(icon: "square.grid.2x2", title: NSLocalizedString("Keşfet", comment: "")),
            PinlyTabItem(icon: "map", title: NSLocalizedString("Rotalar", comment: "")),
            PinlyTabItem(icon: "person.crop.circle", title: NSLocalizedString("Profil", comment: "")),
        ]
    }

    var body: some View {
        GeometryReader { rootGeo in
            // Fiziksel home indicator yüksekliği — bar'ı GERÇEKTEN fiziksel alt kenara
            // kaydırmak için kullanılır (bkz. PinlyTabBar.extraBottomInset yorumu).
            let bottomInset = rootGeo.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                TabView(selection: $selectedTab) {
                    MainTab(selectedTab: $selectedTab)
                        .toolbar(.hidden, for: .tabBar)
                        .tag(0)

                    DiscoverView()
                        .toolbar(.hidden, for: .tabBar)
                        .tag(1)

                    SavedRoutesView()
                        .toolbar(.hidden, for: .tabBar)
                        .tag(2)

                    ProfileTab(selectedTab: $selectedTab)
                        .toolbar(.hidden, for: .tabBar)
                        .tag(3)
                }
                .tint(PinlyTheme.primary)
                // TabView içeriği için görünmez boşluk — gerçek bar aşağıda overlay olarak
                // çizilir. `.safeAreaInset` içine konan view'da `.ignoresSafeArea` fiziksel alt
                // kenara ulaşmıyor (SwiftUI o slot'u kendi ayırdığı alana klipliyor) — bu yüzden
                // TabView'in boşluğu görünmez bir spacer'la, gerçek bar ise overlay'le sağlanıyor.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: PinlyTabBar.reservedHeight(extraBottomInset: bottomInset))
                }

                // Rozet banner — tüm sekmelerin üzerinde. `.id(badge)` ŞART: kimliksiz
                // olunca SwiftUI aynı banner'ı "aynı view" sayıp `.onAppear`'ı bir daha
                // tetiklemeyebiliyordu VEYA arka arkaya iki rozet açılınca (ör. yakın
                // mekan eklerken art arda check tetiklenmesi) eski banner'ın 3 saniyelik
                // auto-dismiss zamanlayıcısı YENİ banner göründükten SONRA da ateşleyip
                // `removeFirst()`'ü dizide eleman kalmamışken çağırıyordu — gerçek cihazda
                // görülen "Fatal error: Can't remove first element from an empty
                // collection" çökmesinin kaynağı buydu. `.id` her rozet için taze bir
                // view (taze zamanlayıcı) garantiler; `isEmpty` kontrolü de ikinci bir
                // güvenlik katmanı.
                if let badge = placeStore.pendingBadges.first {
                    BadgeBannerView(badge: badge) {
                        if !placeStore.pendingBadges.isEmpty {
                            placeStore.pendingBadges.removeFirst()
                        }
                    }
                    .id(badge)
                    .padding(.top, 56)
                    .zIndex(999)
                }
            }
            // Yüzen çentikli tab bar — fiziksel alt kenara kadar kayıyor (bkz. extraBottomInset)
            .overlay(alignment: .bottom) {
                PinlyTabBar(selection: $selectedTab, items: tabItems, extraBottomInset: bottomInset)
                    .ignoresSafeArea([.container, .keyboard], edges: .bottom)
            }
        }
        // Deep link handler
        .onOpenURL { url in
            if url.host == "navigation", routeManager.isNavigating {
                showNavigationFromDeepLink = true
            } else if url.host == "quickadd" {
                showQuickAdd = true
            }
        }
        .fullScreenCover(isPresented: $showNavigationFromDeepLink) {
            NavigationStack {
                RouteSummaryView()
                    .environmentObject(routeManager)
                    .environmentObject(locationManager)
                    .environment(\.dismissRouteFlow, { showNavigationFromDeepLink = false })
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
                .environmentObject(locationManager)
                .environmentObject(placeStore)
        }
        .onAppear {
            checkFirstRouteFlow()
        }
        // Kabul/atla FARKETMEKSİZİN, cover TAMAMEN kapandıktan SONRA bayrağı yak ve varsa
        // bekleyen rotayı başlat — sökülmekte olan bir view'dan yeni bir fullScreenCover
        // sunmaya çalışmak no-op olabiliyor (bkz. FAZ 1 soft-paywall dismiss bug'ı, aynı sınıf hata).
        .fullScreenCover(isPresented: $showFirstRouteSetup, onDismiss: {
            firstRouteFlowShown = true
            if let route = pendingFirstRoute {
                pendingFirstRoute = nil
                startFirstRoute(route)
            }
        }) {
            FirstRouteSetupView(
                onRouteReady: { route in
                    pendingFirstRoute = route
                    showFirstRouteSetup = false
                },
                onSkip: { showFirstRouteSetup = false }
            )
            .environmentObject(locationManager)
            .environmentObject(languageManager)
        }
        .fullScreenCover(isPresented: $showFirstRouteSummary) {
            NavigationStack {
                RouteSummaryView()
                    .environmentObject(routeManager)
                    .environmentObject(locationManager)
                    .environment(\.dismissRouteFlow, { showFirstRouteSummary = false })
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        .id(languageManager.refreshID)
    }

    // MARK: - İlk Rota Kurulumu (FAZ 4)

    private func checkFirstRouteFlow() {
        guard !hasCheckedFirstRouteFlow else { return }
        hasCheckedFirstRouteFlow = true
        guard !firstRouteFlowShown, placeStore.places.isEmpty else { return }
        showFirstRouteSetup = true
    }

    /// `FirstRouteSetupView`'da zaten oluşturulup kaydedilmiş `SavedRoute`'u mevcut
    /// navigasyon desenine (`SavedRoutesViewModel.loadAndStart`) sokup RouteSummaryView'i açar —
    /// aynı badge/analytics kayıtları normal "kayıtlı rotayı başlat" akışıyla birebir aynı.
    private func startFirstRoute(_ route: SavedRoute) {
        SavedRoutesViewModel().loadAndStart(route, into: routeManager, context: modelContext)
        showFirstRouteSummary = true
    }
}
