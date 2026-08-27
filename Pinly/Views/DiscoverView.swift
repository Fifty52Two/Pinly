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
    @Environment(\.nearbySearch) private var nearbySearch
    @Environment(\.analytics) private var analytics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var savedRoutes: [SavedRoute]

    // Filtreler
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var showUnvisitedOnly = false

    // Harita
    // `.automatic` KULLANILMIYOR: harita İÇERİĞİ her değiştiğinde (Yakınımda önerileri
    // yenilenince) kamerayı yeniden çerçeveliyor, bu da `position` binding'ine geri yazıyor,
    // bu da body'yi yeniden değerlendirip yeni içerik üretiyor → kendi kendini besleyen
    // render döngüsü ve görünür panel titremesi. `.userLocation` içerik değişiminde yeniden
    // çerçeveleme YAPMAZ, döngü bu sayede kırılır.
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )
    @State private var selectedPlace: Place? = nil

    // Panel — native `.sheet` DENENDİ ama sheet UIKit'te TÜM PENCEREYİ kaplayan modal bir
    // katman; HomeView'daki floating PinlyTabBar (custom `.overlay`) SwiftUI hiyerarşisinde
    // ayrı bir dal olduğu için sheet'in ALTINDA kalıp kayboluyordu (Keşfet'e girince bar
    // gizleniyordu şikayeti). Panel bu yüzden embedded (view hiyerarşisinin İÇİNDE) yapıya
    // geri alındı — bu sefer tab bar'ın kapladığı alan da hesaba katılarak (bkz. tabBarClearance).
    @State private var panelDetent: PanelDetent = .half
    // `@GestureState` KASITLI OLARAK kullanılmıyor — gesture biter bitmez otomatik olarak
    // (KENDİ implicit animasyonuyla) 0'a dönüyor, bu da `.animation(value: panelDetent)`
    // spring'iyle AYNI ANDA, İKİ AYRI transaction olarak tetiklenip panel bırakılırken
    // görünür bir "titreme/sıçrama" yaratıyordu (gerçek cihazdaki şikayet buydu). Düz
    // `@State` + `.onChanged`/`.onEnded` ile TEK bir `withAnimation` transaction'ı içinde
    // hem offset'i sıfırlayıp hem detent'i değiştirerek bu çakışma ortadan kaldırılıyor.
    @State private var panelDrag: CGFloat = 0

    enum PanelDetent {
        case collapsed, half, expanded

        /// VoiceOver'ın adjustable action'ı için bir sonraki/önceki basamak (Slider'daki gibi).
        func expanded() -> PanelDetent {
            switch self {
            case .collapsed: return .half
            case .half, .expanded: return .expanded
            }
        }

        func collapsed() -> PanelDetent {
            switch self {
            case .expanded: return .half
            case .half, .collapsed: return .collapsed
            }
        }

        var accessibilityDescription: String {
            switch self {
            case .collapsed: return NSLocalizedString("Daraltılmış", comment: "")
            case .half:      return NSLocalizedString("Yarım", comment: "")
            case .expanded:  return NSLocalizedString("Genişletilmiş", comment: "")
            }
        }
    }

    // Wow #2: kategori kartı → detay listesi zoom geçişi (iOS 18+, specs/FAZ6_UI_YON.md)
    @Namespace private var zoomNamespace

    // Yakınımda önerileri
    @State private var nearbySuggestions: [NearbyPlace] = []
    @State private var addedNearbyIDs: Set<String> = []
    @State private var showNearbyAll = false

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
            // NearbyPlacesView kendi NavigationStack'ini içerir.
            // Seçili kategori TAŞINIYOR: aksi halde kullanıcı karışık bir öneri şeridinden
            // "Tümünü Gör"e basıp hep restoran listesine düşüyordu.
            NearbyPlacesView(initialCategory: selectedCategory)
                .environmentObject(locationManager)
                .environmentObject(placeStore)
        }
        .task(id: taskKey) {
            await loadNearbySuggestions()
        }
    }

    /// Konum veya seçili kategori değişince önerileri yenilemek için task kimliği.
    /// Koordinat ~1 km hassasiyete (2 ondalık) yuvarlanır — küçük GPS salınımları
    /// her seferinde 9 MKLocalSearch isteği tetiklemesin.
    private var taskKey: String {
        let coord = locationManager.userLocation?.coordinate
        let lat = coord.map { (($0.latitude  * 100).rounded() / 100) } ?? 0.0
        let lon = coord.map { (($0.longitude * 100).rounded() / 100) } ?? 0.0
        return "\(selectedCategory?.rawValue ?? "-")|\(lat)|\(lon)"
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
                        .accessibilityLabel(place.name)
                    }
                }
            }
            // Yakınımda önerileri — önceden SADECE alt panelde kart olarak listeleniyordu,
            // haritada hiç görünmüyorlardı (kullanıcı "haritada keşfedilecek yerleri görme
            // çalışmıyor" dedi — Apple'ın kendi POI etiketleri görünüp TIKLANAMADIĞI için
            // öyle hissettiriyordu). Kayıtlı mekanlardan ayrışsın diye kesikli/anahat stil.
            ForEach(nearbySuggestions) { nearby in
                Annotation(nearby.name, coordinate: nearby.coordinate) {
                    Button {
                        addNearbyPlace(nearby)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PinlyTheme.surface)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        style: StrokeStyle(lineWidth: 2, dash: [3, 2])
                                    )
                                    .foregroundColor(nearby.category.color)
                                )
                            Image(systemName: isAlreadySaved(nearby) ? "checkmark" : nearby.category.icon)
                                .font(.caption2)
                                .foregroundColor(nearby.category.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAlreadySaved(nearby))
                    .accessibilityLabel(nearby.name)
                }
            }
        }
        // Apple'ın varsayılan POI etiketleri (restoran/kafe adları) burada KAPALI —
        // haritada görünüp tıklanamadıkları için "çalışmıyor" izlenimi veriyorlardı;
        // artık haritadaki TEK etkileşimli katman kendi mekanlarımız + Yakınımda önerileri.
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Çekilebilir panel

    /// HomeView'daki yüzen `PinlyTabBar` bu ekranın DIŞINDA (`.overlay` ile) çizilip
    /// EN ÜSTTE duruyor — panel bu payı bilmeden tam ekran yüksekliğine göre
    /// konumlanırsa daraltılmış hâli barın ARKASINDA/ALTINDA kalır, grabber'a
    /// dokunmak barın hemen üstünde imkansızlaşır. Bar'ın gerçek yüksekliği + home
    /// indicator kadar pay bırakılıyor.
    private var tabBarClearance: CGFloat {
        PinlyTabBar.height
    }

    private func panelHeight(for detent: PanelDetent, in geo: GeometryProxy) -> CGFloat {
        switch detent {
        case .collapsed: return 120
        case .half:      return geo.size.height * 0.45
        case .expanded:  return geo.size.height * 0.88
        }
    }

    private func panel(in geo: GeometryProxy) -> some View {
        let baseHeight = panelHeight(for: panelDetent, in: geo)
        let clampedHeight = min(
            max(baseHeight - panelDrag, panelHeight(for: .collapsed, in: geo)),
            panelHeight(for: .expanded, in: geo)
        )
        // Panel yüksekliği + tab bar boşluğu — arka plan ekranın altına kadar uzanır,
        // harita alt boşluktan görünmez.
        let totalHeight = clampedHeight + tabBarClearance

        return VStack(spacing: 0) {
            // Grabber + sürükleme alanı — dokunma hedefi Apple HIG'in önerdiği 44pt.
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            panelDrag = value.translation.height
                        }
                        .onEnded { value in
                            let projected = baseHeight - value.predictedEndTranslation.height
                            let candidates: [PanelDetent] = [.collapsed, .half, .expanded]
                            let next = candidates.min {
                                abs(panelHeight(for: $0, in: geo) - projected)
                                    < abs(panelHeight(for: $1, in: geo) - projected)
                            } ?? .half
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                panelDrag = 0
                                panelDetent = next
                            }
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(NSLocalizedString("Panel Yüksekliği", comment: ""))
                .accessibilityValue(panelDetent.accessibilityDescription)
                .accessibilityAdjustableAction { direction in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        switch direction {
                        case .increment: panelDetent = panelDetent.expanded()
                        case .decrement: panelDetent = panelDetent.collapsed()
                        default: break
                        }
                    }
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nearbySection
                    collectionSection
                }
                .padding(.top, 4)
                .padding(.bottom, 24 + tabBarClearance)
            }
            .scrollDisabled(panelDetent != .expanded)

            Spacer(minLength: 0)
        }
        .frame(height: totalHeight)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(PinlyTheme.ground)
                .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
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

            if locationManager.userLocation == nil {
                Text(NSLocalizedString("Konum alınıyor…", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else if nearbySuggestions.isEmpty {
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
                                isAdded: isAlreadySaved(nearby)
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
                                .pinlyZoomDestination(id: cat.rawValue, in: zoomNamespace)
                        } label: {
                            CategoryDiscoverCard(category: cat, count: places.count)
                        }
                        .buttonStyle(.plain)
                        .pinlyZoomSource(id: cat.rawValue, in: zoomNamespace)
                        .discoverCardScrollTransition(skipsAnimation: reduceMotion || panelDetent != .expanded)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Aksiyonlar

    private func loadNearbySuggestions() async {
        guard let coord = locationManager.userLocation?.coordinate else { return }
        if let category = selectedCategory {
            let found = await nearbySearch.searchNearby(coordinate: coord, category: category, radiusMeters: 1000)
            nearbySuggestions = Array(found.prefix(5))
            return
        }
        // "Tümü" seçiliyken — Apple MKLocalSearch rate-limit aşımını önlemek için 3'erli batch'ler halinde aranır
        var merged: [NearbyPlace] = []
        let categories = PlaceCategory.allCases
        let batchSize = 3
        for i in stride(from: 0, to: categories.count, by: batchSize) {
            let batch = Array(categories[i..<min(i + batchSize, categories.count)])
            let batchResults = await withTaskGroup(of: [NearbyPlace].self) { group in
                for category in batch {
                    group.addTask {
                        await nearbySearch.searchNearby(coordinate: coord, category: category, radiusMeters: 1000)
                    }
                }
                var res: [NearbyPlace] = []
                for await r in group { res.append(contentsOf: r) }
                return res
            }
            merged.append(contentsOf: batchResults)
        }
        // Tekilleştirme ŞART: "Tümü" modunda 8 kategori ayrı ayrı aranıyor ve `.general`
        // metin sorgusu sonuçları gerçek kategorilerine yeniden damgalandığı için aynı
        // mekan birden fazla batch'ten dönebiliyor. `NearbyPlace.id` artık isim+koordinattan
        // türeyen STABİL bir değer olduğundan mükerrer kayıtlar aynı kimliğe çarpar ve
        // `ForEach` yinelenen ID uyarısı verirdi.
        var seen = Set<String>()
        nearbySuggestions = merged
            .sorted { $0.distanceMeters < $1.distanceMeters }
            .filter { seen.insert($0.id).inserted }
            .prefix(5)
            .map { $0 }
    }

    /// `addedNearbyIDs` yalnızca bu oturumda eklenenleri bilir; uygulama kapanıp açılınca
    /// sıfırlanıyor ve kullanıcı AYNI mekanı ikinci kez ekleyebiliyordu. Gerçek koleksiyon
    /// da kontrol ediliyor (aynı isim + ~50 m yakınlık = aynı mekan).
    private func isAlreadySaved(_ nearby: NearbyPlace) -> Bool {
        if addedNearbyIDs.contains(nearby.id) { return true }
        return placeStore.places.contains { saved in
            guard saved.name == nearby.name, let coord = saved.coordinate else { return false }
            return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                .distance(from: CLLocation(latitude: nearby.coordinate.latitude,
                                           longitude: nearby.coordinate.longitude)) < 50
        }
    }

    private func addNearbyPlace(_ nearby: NearbyPlace) {
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
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? PinlyTheme.onAccent : .primary)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(place.formattedDistance)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .accessibilityHidden(true)
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
            .accessibilityLabel(isAdded
                ? NSLocalizedString("Eklendi", comment: "")
                : String(format: NSLocalizedString("%@ ekle", comment: ""), place.name))
        }
        .padding(10)
        .frame(width: 170, alignment: .leading)
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
            .accessibilityHidden(true)
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
            .accessibilityHidden(true)
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: NSLocalizedString("%lld üzerinden %lld yıldız", comment: ""), 5, rating))
                }
            }
            Spacer()
            if place.isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PinlyTheme.success)
                    .font(.subheadline)
                    .accessibilityLabel(NSLocalizedString("Ziyaret Edildi", comment: ""))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// `scrollTransition`'ın body closure'ı nonisolated'dır — `@Environment(\.accessibilityReduceMotion)`
    /// gibi MainActor-izoleli bir property'yi doğrudan içeriden okumak Swift 6'da uyarı/hataya yol açar.
    /// Değer çağrı yerinde (MainActor) yakalanıp closure'a düz bir `Bool` olarak geçirilir.
    func discoverCardScrollTransition(skipsAnimation: Bool) -> some View {
        scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity || skipsAnimation ? 1 : 0.85)
                .scaleEffect(phase.isIdentity || skipsAnimation ? 1 : 0.96)
        }
    }
}
