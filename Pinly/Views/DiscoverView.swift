import SwiftUI
import SwiftData
import MapKit

// MARK: - Discover (Keşfet) Ekranı
//
// FAZ 4 (kullanıcı onaylı düzen): tam ekran harita ana içerik — tüm mekanlar pin,
// üstte kategori + "Gitmediklerim" filtre chip'leri, alttan çekilebilir panelde
// Yakınımda öneri şeridi + hazır rotalar + Koleksiyonum grid'i (Apple Maps deseni).

struct DiscoverView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements
    @Environment(\.nearbySearch) private var nearbySearch
    @Environment(\.starterRoutes) private var starterRoutes
    @Environment(\.analytics) private var analytics
    @Query private var savedRoutes: [SavedRoute]

    // Filtreler
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var showUnvisitedOnly = false

    // Harita
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPlace: Place? = nil

    // Panel
    @State private var panelDetent: PanelDetent = .half
    @GestureState private var panelDrag: CGFloat = 0

    // Yakınımda önerileri
    @State private var nearbySuggestions: [NearbyPlace] = []
    @State private var addedNearbyIDs: Set<UUID> = []
    @State private var showNearbyAll = false
    @State private var showPaywall = false

    enum PanelDetent { case collapsed, half, expanded }

    // MARK: Türetilmiş veriler

    private var filteredPlaces: [Place] {
        placeStore.places.filter { place in
            if showUnvisitedOnly && place.isVisited { return false }
            if let cat = selectedCategory, PlaceCategory.from(place.category) != cat { return false }
            return true
        }
    }

    private var categoriesWithPlaces: [(PlaceCategory, [Place])] {
        PlaceCategory.allCases.compactMap { cat in
            let places = placeStore.places.filter { PlaceCategory.from($0.category) == cat }
            return places.isEmpty ? nil : (cat, places)
        }
    }

    private var availableStarters: [StarterRouteDefinition] {
        let existing = Set(savedRoutes.map(\.name))
        return starterRoutes.loadAll().filter { !existing.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    discoverMap
                    filterBar
                    panel(in: geo)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
        .sheet(item: $selectedPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
            }
        }
        .sheet(isPresented: $showNearbyAll) {
            // NearbyPlacesView kendi NavigationStack'ini içerir
            NearbyPlacesView()
                .environmentObject(locationManager)
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
        .task(id: taskKey) {
            await loadNearbySuggestions()
        }
    }

    /// Konum veya seçili kategori değişince önerileri yenilemek için task kimliği
    private var taskKey: String {
        let coord = locationManager.userLocation?.coordinate
        return "\(selectedCategory?.rawValue ?? "-")|\(coord?.latitude ?? 0)|\(coord?.longitude ?? 0)"
    }

    // MARK: - Harita

    private var discoverMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(filteredPlaces, id: \.id) { place in
                if let coord = place.coordinate {
                    let cat = PlaceCategory.from(place.category)
                    Annotation(place.name, coordinate: coord) {
                        Button {
                            selectedPlace = place
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(place.isVisited ? cat.color.opacity(0.45) : cat.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                Image(systemName: cat.icon)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Filtre çubuğu

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DiscoverFilterChip(
                    title: NSLocalizedString("Tümü", comment: ""),
                    color: PinlyTheme.primary,
                    isSelected: selectedCategory == nil
                ) { selectedCategory = nil }

                DiscoverFilterChip(
                    title: NSLocalizedString("Gitmediklerim", comment: ""),
                    icon: "bookmark",
                    color: PinlyTheme.accent,
                    isSelected: showUnvisitedOnly
                ) { showUnvisitedOnly.toggle() }

                ForEach(PlaceCategory.allCases, id: \.self) { cat in
                    DiscoverFilterChip(
                        title: cat.localizedName,
                        icon: cat.icon,
                        color: cat.color,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Çekilebilir panel

    private func panelHeight(for detent: PanelDetent, in geo: GeometryProxy) -> CGFloat {
        switch detent {
        case .collapsed: return 120
        case .half:      return geo.size.height * 0.45
        case .expanded:  return geo.size.height * 0.88
        }
    }

    private func panel(in geo: GeometryProxy) -> some View {
        let baseHeight = panelHeight(for: panelDetent, in: geo)
        let height = min(
            max(baseHeight - panelDrag, panelHeight(for: .collapsed, in: geo)),
            panelHeight(for: .expanded, in: geo)
        )

        return VStack(spacing: 0) {
            // Grabber + sürükleme alanı
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .updating($panelDrag) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let projected = baseHeight - value.predictedEndTranslation.height
                            let candidates: [PanelDetent] = [.collapsed, .half, .expanded]
                            panelDetent = candidates.min {
                                abs(panelHeight(for: $0, in: geo) - projected)
                                    < abs(panelHeight(for: $1, in: geo) - projected)
                            } ?? .half
                        }
                )

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nearbySection
                    starterRoutesSection
                    collectionSection
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDisabled(panelDetent != .expanded)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(PinlyTheme.surface)
                .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: panelDetent)
    }

    // MARK: - Yakınımda şeridi

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("Yakınımda", comment: ""))
                    .font(.headline)
                Spacer()
                Button {
                    showNearbyAll = true
                } label: {
                    Text(NSLocalizedString("Tümünü Gör", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(PinlyTheme.primary)
                }
            }
            .padding(.horizontal, 16)

            if nearbySuggestions.isEmpty {
                Text(NSLocalizedString("Çevrende öneri bulunamadı.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(nearbySuggestions) { nearby in
                            NearbySuggestionCard(
                                place: nearby,
                                isAdded: addedNearbyIDs.contains(nearby.id)
                            ) {
                                addNearbyPlace(nearby)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Hazır rotalar şeridi

    @ViewBuilder
    private var starterRoutesSection: some View {
        if !availableStarters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("Hazır Rotalar", comment: ""))
                    .font(.headline)
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableStarters) { definition in
                            StarterRouteMiniCard(definition: definition) {
                                modelContext.insert(starterRoutes.makeSavedRoute(from: definition))
                                try? modelContext.save()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Koleksiyonum

    @ViewBuilder
    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Koleksiyonum", comment: ""))
                .font(.headline)
                .padding(.horizontal, 16)

            if categoriesWithPlaces.isEmpty {
                Text(NSLocalizedString("Henüz mekan yok. Yakınımda önerilerinden veya Mekanlarım ekranından ekleyebilirsin.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categoriesWithPlaces, id: \.0.rawValue) { cat, places in
                        NavigationLink {
                            CategoryPlacesView(category: cat, places: places)
                        } label: {
                            CategoryDiscoverCard(category: cat, count: places.count)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Aksiyonlar

    private func loadNearbySuggestions() async {
        guard let coord = locationManager.userLocation?.coordinate else { return }
        let found = await nearbySearch.searchNearby(
            coordinate: coord,
            category: selectedCategory ?? .restaurant,
            radiusMeters: 1000
        )
        nearbySuggestions = Array(found.prefix(5))
    }

    private func addNearbyPlace(_ nearby: NearbyPlace) {
        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else {
            showPaywall = true
            return
        }
        Task {
            await placeStore.addPlace(
                name: nearby.name,
                category: nearby.category.rawValue,
                address: nearby.address,
                notes: "",
                coordinate: nearby.coordinate,
                context: modelContext
            )
            addedNearbyIDs.insert(nearby.id)
            analytics.track(.placeAdded(source: .nearby))
        }
    }
}

// MARK: - Filtre Chip

private struct DiscoverFilterChip: View {
    let title: String
    var icon: String? = nil
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isSelected ? color : PinlyTheme.surface)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? color : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Yakınımda öneri kartı

private struct NearbySuggestionCard: View {
    let place: NearbyPlace
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(place.category.color.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: place.category.icon)
                        .font(.caption)
                        .foregroundColor(place.category.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(place.formattedDistance)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                    Text(isAdded
                         ? NSLocalizedString("Eklendi", comment: "")
                         : NSLocalizedString("Ekle", comment: ""))
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(isAdded ? PinlyTheme.success : PinlyTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill((isAdded ? PinlyTheme.success : PinlyTheme.primary).opacity(0.10))
                )
            }
            .disabled(isAdded)
        }
        .padding(10)
        .frame(width: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
    }
}

// MARK: - Hazır rota mini kartı

private struct StarterRouteMiniCard: View {
    let definition: StarterRouteDefinition
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.caption)
                    .foregroundColor(PinlyTheme.primary)
                Text(definition.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(definition.places.prefix(2).map(\.name).joined(separator: " → ")
                 + (definition.places.count > 2 ? " +\(definition.places.count - 2)" : ""))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text(NSLocalizedString("Rotalarıma Ekle", comment: ""))
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(PinlyTheme.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Capsule().fill(PinlyTheme.slate.opacity(0.10)))
            }
        }
        .padding(10)
        .frame(width: 200, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
    }
}

// MARK: - Kategori Kart

struct CategoryDiscoverCard: View {
    let category: PlaceCategory
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(category.color)
            }
            Text(category.localizedName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(String(format: NSLocalizedString("%lld mekan", comment: ""), count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PinlyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(category.color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Kategori Detay Listesi

struct CategoryPlacesView: View {
    let category: PlaceCategory
    let places: [Place]

    private var visitedPlaces: [Place] { places.filter { $0.isVisited } }
    private var unvisitedPlaces: [Place] { places.filter { !$0.isVisited } }

    var body: some View {
        List {
            if !unvisitedPlaces.isEmpty {
                Section("\(NSLocalizedString("Gidilecek", comment: "")) (\(unvisitedPlaces.count))") {
                    ForEach(unvisitedPlaces, id: \.id) { place in
                        CategoryPlaceRow(place: place, category: category)
                    }
                }
            }
            if !visitedPlaces.isEmpty {
                Section("\(NSLocalizedString("Ziyaret Edildi", comment: "")) (\(visitedPlaces.count))") {
                    ForEach(visitedPlaces, id: \.id) { place in
                        CategoryPlaceRow(place: place, category: category)
                    }
                }
            }
        }
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CategoryPlaceRow: View {
    let place: Place
    let category: PlaceCategory

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.callout)
                    .foregroundColor(category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let rating = place.userRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(star <= rating ? PinlyTheme.ratingStar : .secondary)
                        }
                    }
                }
            }
            Spacer()
            if place.isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PinlyTheme.success)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
