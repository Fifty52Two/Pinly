import SwiftUI
import CoreLocation
import MapKit

struct NearbyPlacesView: View {
    /// Keşfet'teki "Tümünü Gör" bu ekranı kullanıcının O ANDA seçili olduğu kategoriyle
    /// açar. Aksi halde karışık bir öneri şeridinden hep `.restaurant` listesine düşülüyor
    /// ve kullanıcı bambaşka bir ekrana geldiğini sanıyordu.
    var initialCategory: PlaceCategory? = nil

    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.nearbySearch) private var nearbySearch
    @Environment(\.modelContext) private var modelContext
    @Environment(\.analytics) private var analytics

    @StateObject private var viewModel = NearbyPlacesViewModel()
    @State private var addedIDs: Set<String> = []
    @State private var showMap = false
    @AppStorage("pinly.nearbyRadiusMeters") private var radiusMeters = 1000.0
    // `.automatic` KULLANILMIYOR — harita içeriği her değiştiğinde kamerayı yeniden
    // çerçeveleyip `position` binding'ine geri yazıyor, bu da body'yi yeniden değerlendirip
    // yeni içerik üretiyor (kendi kendini besleyen render döngüsü). Bkz. `DiscoverView`.
    @State private var mapPosition: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )

    private static let radiusOptions: [Double] = [500, 1000, 2000, 5000]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                categoryPicker
                    .padding(.vertical, 12)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(NSLocalizedString("Aranıyor…", comment: ""))
                    Spacer()
                } else if let err = viewModel.errorMessage {
                    Spacer()
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else if viewModel.results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Yakındaki Mekanları Keşfet", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("Kategori seç ve çevrendeki mekanları bul.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else if showMap {
                    resultsMap
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.results) { place in
                                NearbyPlaceRow(
                                    place: place,
                                    isAdded: isAlreadySaved(place)
                                ) {
                                    addPlace(place)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(PinlyTheme.groundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker(NSLocalizedString("Arama Yarıçapı", comment: ""), selection: $radiusMeters) {
                            ForEach(Self.radiusOptions, id: \.self) { radius in
                                Text(radiusLabel(radius)).tag(radius)
                            }
                        }
                    } label: {
                        Image(systemName: "circle.dashed")
                    }
                    .accessibilityLabel(NSLocalizedString("Arama Yarıçapı", comment: ""))
                    Button {
                        withAnimation { showMap.toggle() }
                    } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                    .accessibilityLabel(NSLocalizedString(showMap ? "Listeyi Göster" : "Haritayı Göster", comment: ""))
                    .disabled(viewModel.results.isEmpty)
                    Button {
                        Task { await runSearch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(NSLocalizedString("Sonuçları Yenile", comment: ""))
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                if let initialCategory {
                    viewModel.selectedCategory = initialCategory
                }
                await runSearch()
            }
            .onChange(of: viewModel.selectedCategory) {
                Task { await runSearch() }
            }
            .onChange(of: radiusMeters) {
                Task { await runSearch() }
            }
            // `LocationManager` tek seferlik `requestLocation()` kullanıyor, yani konum
            // ASENKRON geliyor. Bu olmadan: sheet konum gelmeden bir an önce açılırsa
            // `runSearch()` "Konum bilgisi alınamadı." yazıp çıkıyor ve BİR DAHA hiç
            // denemiyordu — ekran kalıcı olarak hatada takılı kalıyordu. Sheet bir saniye
            // geç açılınca çalışması, "bazen çalışıyor bazen çalışmıyor" şikayetinin sebebiydi.
            .onChange(of: locationManager.userLocation?.coordinate.latitude) { _, newValue in
                guard newValue != nil, viewModel.results.isEmpty else { return }
                Task { await runSearch() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(NSLocalizedString("Yakınımda", comment: ""))
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundColor(.primary)
            Text(String(format: NSLocalizedString("%@ yarıçapında %lld mekan", comment: ""), radiusLabel(radiusMeters), viewModel.results.count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PinlyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                )
        )
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlaceCategory.allCases, id: \.self) { cat in
                    Button {
                        viewModel.selectedCategory = cat
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                            Text(cat.localizedName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedCategory == cat
                                ? cat.color
                                : cat.color.opacity(0.12)
                        )
                        .foregroundColor(
                            viewModel.selectedCategory == cat ? .white : cat.color
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var resultsMap: some View {
        Map(position: $mapPosition) {
            UserAnnotation()
            ForEach(viewModel.results) { place in
                Marker(place.name, systemImage: place.category.icon, coordinate: place.coordinate)
                    .tint(place.category.color)
            }
        }
        .mapControlVisibility(.hidden)
        .onAppear {
            if let coord = locationManager.userLocation?.coordinate {
                mapPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: radiusMeters * 2.5,
                    longitudinalMeters: radiusMeters * 2.5
                ))
            }
        }
    }

    private func radiusLabel(_ radius: Double) -> String {
        radius < 1000 ? "\(Int(radius)) m" : "\(Int(radius / 1000)) km"
    }

    private func runSearch() async {
        guard let coord = locationManager.userLocation?.coordinate else {
            viewModel.errorMessage = NSLocalizedString("Konum bilgisi alınamadı.", comment: "")
            return
        }
        await viewModel.search(coordinate: coord, radiusMeters: radiusMeters)
    }

    /// `addedIDs` yalnızca bu oturumda eklenenleri bilir; uygulama kapanıp açılınca
    /// sıfırlanıyor ve kullanıcı AYNI mekanı ikinci kez ekleyebiliyordu. Gerçek koleksiyon
    /// da kontrol ediliyor (aynı isim + ~50 m yakınlık = aynı mekan).
    private func isAlreadySaved(_ nearby: NearbyPlace) -> Bool {
        if addedIDs.contains(nearby.id) { return true }
        return placeStore.places.contains { saved in
            guard saved.name == nearby.name, let coord = saved.coordinate else { return false }
            return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                .distance(from: CLLocation(latitude: nearby.coordinate.latitude,
                                           longitude: nearby.coordinate.longitude)) < 50
        }
    }

    private func addPlace(_ nearby: NearbyPlace) {
        Task {
            await placeStore.addPlace(
                name: nearby.name,
                category: nearby.category.rawValue,
                address: nearby.address,
                notes: "",
                coordinate: nearby.coordinate,
                context: modelContext
            )
            addedIDs.insert(nearby.id)
            analytics.track(.placeAdded(source: .nearby))
        }
    }
}

// MARK: - Row

private struct NearbyPlaceRow: View {
    let place: NearbyPlace
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        // Claude Design mockup'ındaki satır — dolu renkli kare rozet + beyaz glif,
        // sağda mesafe (birebir); artı/tik butonu mevcut ekle işlevi için korunuyor.
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(place.category.color)
                    .frame(width: 34, height: 34)
                Image(systemName: place.category.icon)
                    .font(.callout)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(place.formattedDistance)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onAdd) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundColor(isAdded ? PinlyTheme.success : PinlyTheme.primary)
            }
            .disabled(isAdded)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                )
        )
    }
}
