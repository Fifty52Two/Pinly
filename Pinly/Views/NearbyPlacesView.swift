import SwiftUI
import CoreLocation
import MapKit

struct NearbyPlacesView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.nearbySearch) private var nearbySearch
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements
    @Environment(\.analytics) private var analytics

    @StateObject private var viewModel = NearbyPlacesViewModel()
    @State private var addedIDs: Set<UUID> = []
    @State private var showPaywall = false
    @State private var showMap = false
    @AppStorage("pinly.nearbyRadiusMeters") private var radiusMeters = 1000.0

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
                } else {
                    List(viewModel.results) { place in
                        NearbyPlaceRow(
                            place: place,
                            isAdded: addedIDs.contains(place.id)
                        ) {
                            addPlace(place)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.plain)
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
                    Button {
                        withAnimation { showMap.toggle() }
                    } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                    .disabled(viewModel.results.isEmpty)
                    Button {
                        Task { await runSearch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task { await runSearch() }
            .onChange(of: viewModel.selectedCategory) { _ in
                Task { await runSearch() }
            }
            .onChange(of: radiusMeters) { _ in
                Task { await runSearch() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
        }
    }

    // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki "Yakınımda" header'ı —
    // seigaiha dokulu kart + kalın başlık + yarıçap/sonuç sayısı alt satırı (birebir),
    // sistem large-title'ın yerine. Toolbar (kategori/yarıçap/harita/yenile) korunuyor.
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
        .frame(height: 80)
        .background(
            ZStack {
                PinlyTheme.surface
                Image("SeigaihaPattern")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3)
                    .allowsHitTesting(false)
            }
            .clipped()
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        Map {
            UserAnnotation()
            ForEach(viewModel.results) { place in
                Marker(place.name, systemImage: place.category.icon, coordinate: place.coordinate)
                    .tint(place.category.color)
            }
        }
        .mapControlVisibility(.hidden)
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

    private func addPlace(_ nearby: NearbyPlace) {
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
