import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var placeStore = PlaceStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                ThemeSelectionView {
                    hasSeenOnboarding = true
                }
            } else {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    PermissionView()
                case .denied, .restricted:
                    LocationDeniedView()
                default:
                    HomeView()
                        .environmentObject(placeStore)
                        .environmentObject(locationManager)
                        .environmentObject(routeManager)
                }
            }
        }
        .onAppear {
            hasSeenOnboarding = false // TEMP: remove before shipping
            placeStore.load(context: modelContext)
        }
    }
}

// MARK: - Nav Tab

enum NavTab: CaseIterable {
    case explore, routes, add, saved, profile

    var icon: String {
        switch self {
        case .explore: return "safari.fill"
        case .routes:  return "figure.walk"
        case .add:     return "plus"
        case .saved:   return "bookmark.fill"
        case .profile: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .explore: return "EXPLORE"
        case .routes:  return "ROUTES"
        case .add:     return "ADD"
        case .saved:   return "SAVED"
        case .profile: return "PROFILE"
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var activeTab: NavTab? = nil   // nil = nothing selected
    @State private var showExplore = false
    @State private var showRouteFlow = false
    @State private var showSaved = false
    @State private var showAddPlace = false
    @State private var showProfile = false
    @State private var routeTrim: CGFloat = 0

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var body: some View {
        ZStack(alignment: .bottom) {
            t.bg.ignoresSafeArea()
            GeometryReader { geo in homeRouteBackground(size: geo.size) }

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 17))
                            .foregroundColor(t.primary)
                        Text("CURATOR ROUTES")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(t.title)
                    }
                    Spacer()
                    if !locationManager.currentDistrict.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill").font(.system(size: 10))
                            Text(locationManager.currentDistrict)
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.3)
                        }
                        .foregroundColor(t.primary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(t.accent.opacity(0.15)))
                        .overlay(Capsule().stroke(t.accent.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.top, 64)
                .padding(.horizontal, 24)

                Spacer()

                // Headline
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your day,\nintelligently\nmapped.")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(t.title)
                        .tracking(-0.5)
                        .lineSpacing(2)
                    Text("Plan your perfect route across the city.")
                        .font(.system(size: 14))
                        .foregroundColor(t.subtitle)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer()
                Spacer().frame(height: 110) // room for nav bar
            }

            // Bottom nav bar — direct callbacks, no binding
            CuratorNavBar(active: activeTab, t: t,
                onExplore: { showExplore = true },
                onRoutes:  { showRouteFlow = true },
                onAdd:     { showAddPlace = true },
                onSaved:   { showSaved = true },
                onProfile: { showProfile = true }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                routeTrim = 1
            }
        }
        .fullScreenCover(isPresented: $showExplore) {
            ExploreView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
        .fullScreenCover(isPresented: $showRouteFlow) {
            CategoryPickerView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
                .environment(\.dismissRouteFlow, {
                    showRouteFlow = false
                    locationManager.stopNavigationTracking()
                    routeManager.reset()
                })
        }
        .fullScreenCover(isPresented: $showSaved) {
            PlacesListView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView().environmentObject(placeStore)
        }
    }

    @ViewBuilder
    private func homeRouteBackground(size: CGSize) -> some View {
        let sx = size.width  / 400
        let sy = size.height / 800

        ZStack {
            OnboardingRoutePath()
                .stroke(t.accent.opacity(0.10),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: size.width, height: size.height)
            OnboardingRoutePath()
                .trim(from: 0, to: routeTrim)
                .stroke(t.accent.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: size.width, height: size.height)
            Circle()
                .fill(t.primary.opacity(0.12))
                .frame(width: 24, height: 24)
                .overlay(Circle().fill(t.primary).frame(width: 8, height: 8))
                .position(x: 200 * sx, y: 100 * sy)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Curator Nav Bar

struct CuratorNavBar: View {
    let active: NavTab?
    let t: ThemeColors
    let onExplore: () -> Void
    let onRoutes:  () -> Void
    let onAdd:     () -> Void
    let onSaved:   () -> Void
    let onProfile: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            navButton(.explore, action: onExplore)
            navButton(.routes,  action: onRoutes)
            navButton(.add,     action: onAdd)
            navButton(.saved,   action: onSaved)
            navButton(.profile, action: onProfile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .background(t.bg.shadow(color: .black.opacity(0.06), radius: 16, y: -4))
    }

    @ViewBuilder
    private func navButton(_ tab: NavTab, action: @escaping () -> Void) -> some View {
        let isActive = active == tab
        Button(action: action) {
            VStack(spacing: 5) {
                if isActive {
                    // Active: no circle, icon in primary color
                    Image(systemName: tab.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(t.primary)
                        .frame(width: 44, height: 44)
                } else {
                    // Inactive: gray circle with icon
                    ZStack {
                        Circle()
                            .fill(t.card)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                        Image(systemName: tab.icon)
                            .font(.system(size: 17))
                            .foregroundColor(t.subtitle.opacity(0.65))
                    }
                }
                Text(tab.label)
                    .font(.system(size: 9, weight: isActive ? .bold : .regular))
                    .tracking(1.2)
                    .foregroundColor(isActive ? t.primary : t.subtitle.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Places List View

struct PlacesListView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var showAddPlace = false
    @State private var selectedCategory: String? = nil

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var allCategories: [String] { placeStore.allCategories }

    var sortedPlaces: [Place] {
        let filtered: [Place]
        if let cat = selectedCategory {
            filtered = placeStore.places.filter { $0.category == cat }
        } else {
            filtered = placeStore.places
        }
        guard let userLoc = locationManager.userLocation else { return filtered }
        return filtered.sorted { a, b in
            guard let coordA = a.coordinate, let coordB = b.coordinate else { return false }
            let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
            let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
            return userLoc.distance(from: locA) < userLoc.distance(from: locB)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(t.subtitle)
                            .padding(10)
                            .background(Circle().fill(t.card))
                            .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Mekanlarım")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(0.2)
                        .foregroundColor(t.title)

                    Spacer()

                    Button { showAddPlace = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(t.buttonText)
                            .padding(10)
                            .background(Circle().fill(t.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                if sortedPlaces.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 44))
                            .foregroundColor(t.primary.opacity(0.4))
                        Text("Henüz mekan eklenmedi")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(t.title)
                        Text("+ butonuna basarak mekan ekleyebilirsin")
                            .font(.system(size: 13))
                            .foregroundColor(t.subtitle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    Text("\(sortedPlaces.count) mekan")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .foregroundColor(t.subtitle.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)

                    if !allCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "All" chip
                                Button {
                                    withAnimation(.spring(response: 0.3)) { selectedCategory = nil }
                                } label: {
                                    Text("Tümü")
                                        .font(.system(size: 12, weight: selectedCategory == nil ? .semibold : .regular))
                                        .foregroundColor(selectedCategory == nil ? t.buttonText : t.subtitle)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(selectedCategory == nil ? t.accent : t.card))
                                        .overlay(Capsule().stroke(selectedCategory == nil ? Color.clear : t.cardBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                ForEach(allCategories, id: \.self) { cat in
                                    let isActive = selectedCategory == cat
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCategory = isActive ? nil : cat
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: PlaceStyle.icon(for: cat))
                                                .font(.system(size: 10))
                                            Text(cat)
                                                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                                        }
                                        .foregroundColor(isActive ? t.buttonText : t.subtitle)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(isActive ? t.accent : t.card))
                                        .overlay(Capsule().stroke(isActive ? Color.clear : t.cardBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 10)
                    }

                    List {
                        ForEach(sortedPlaces) { place in
                            PlaceListItemView(place: place, modelContext: modelContext, t: t)
                                .listRowBackground(t.card)
                                .listRowSeparatorTint(t.separator)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                placeStore.deletePlace(sortedPlaces[index], context: modelContext)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView().environmentObject(placeStore)
        }
    }
}

// MARK: - Place List Item

struct PlaceListItemView: View {
    let place: Place
    let modelContext: ModelContext
    let t: ThemeColors
    @EnvironmentObject var placeStore: PlaceStore
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(place.categoryColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: place.categoryIcon)
                    .foregroundColor(place.categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(place.isVisited ? t.subtitle : t.title)
                    .strikethrough(place.isVisited, color: t.subtitle)
                Text(place.category)
                    .font(.system(size: 11))
                    .foregroundColor(t.subtitle.opacity(0.7))
                if place.visitCount > 0 {
                    Text("\(place.visitCount)x ziyaret edildi")
                        .font(.system(size: 10))
                        .foregroundColor(t.primary.opacity(0.7))
                }
                if let rating = place.userRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundColor(star <= rating ? t.accent : t.subtitle.opacity(0.3))
                        }
                    }
                }
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.system(size: 10))
                        .foregroundColor(t.subtitle.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        place.isVisited.toggle()
                        try? modelContext.save()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(place.isVisited ? t.primary : t.subtitle.opacity(0.3))
                }
                .buttonStyle(.plain)

                Button { showEdit = true } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundColor(t.accent.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showEdit) {
            EditPlaceView(place: place).environmentObject(placeStore)
        }
    }
}

// MARK: - Permission View

struct PermissionView: View {
    @AppStorage("appTheme") private var storedTheme = "light"
    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 17))
                        .foregroundColor(t.primary)
                    Text("CURATOR ROUTES")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(t.title)
                }
                .padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(t.accent)
                        .padding(.bottom, 4)
                    Text("Konumuna\nihtiyacımız var")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(t.title)
                        .tracking(-0.5)
                        .lineSpacing(2)
                    Text("Bulunduğun semtteki mekanları göstermek için konum izni gerekiyor.")
                        .font(.system(size: 15))
                        .foregroundColor(t.subtitle)
                        .lineSpacing(4)
                        .frame(maxWidth: 280, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Location Denied View

struct LocationDeniedView: View {
    @AppStorage("appTheme") private var storedTheme = "light"
    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 17))
                        .foregroundColor(t.primary)
                    Text("CURATOR ROUTES")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(t.title)
                }
                .padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(t.destructive)
                        .padding(.bottom, 4)
                    Text("Konum izni\ngerekli")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(t.title)
                        .tracking(-0.5)
                        .lineSpacing(2)
                    Text("Ayarlar > NotionGO > Konum bölümünden izin ver.")
                        .font(.system(size: 15))
                        .foregroundColor(t.subtitle)
                        .lineSpacing(4)
                        .frame(maxWidth: 280, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Ayarlara Git")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(t.buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(t.accent)
                        .clipShape(Capsule())
                        .shadow(color: t.accent.opacity(0.25), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
    }
}
