import SwiftUI

// MARK: - Tab Bar Ana Yapısı

struct HomeView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @EnvironmentObject var languageManager: LanguageManager

    // Test/otomasyon: -pinly.selectedTabOverride N ile başlangıç sekmesi seçilebilir
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "pinly.selectedTabOverride")
    @State private var showNavigationFromDeepLink = false
    @State private var showQuickAdd = false

    private var tabItems: [PinlyTabItem] {
        [
            PinlyTabItem(icon: "house", title: NSLocalizedString("Ana", comment: "")),
            PinlyTabItem(icon: "square.grid.2x2", title: NSLocalizedString("Keşfet", comment: "")),
            PinlyTabItem(icon: "map", title: NSLocalizedString("Rotalar", comment: "")),
            PinlyTabItem(icon: "person.crop.circle", title: NSLocalizedString("Profil", comment: "")),
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                MainTab()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(0)

                DiscoverView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)

                SavedRoutesView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(2)

                ProfileTab()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(3)
            }
            .tint(PinlyTheme.primary)
            // Yüzen çentikli tab bar — safe area inset olduğu için
            // listeler/scroll'lar içeriğini otomatik olarak üstünde bitirir
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PinlyTabBar(selection: $selectedTab, items: tabItems)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            // Rozet banner — tüm sekmelerin üzerinde
            if let badge = placeStore.pendingBadges.first {
                BadgeBannerView(badge: badge) {
                    placeStore.pendingBadges.removeFirst()
                }
                .padding(.top, 56)
                .zIndex(999)
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
        .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        .id(languageManager.refreshID)
    }
}
