import SwiftUI
import CoreLocation
import MapKit

struct NearbyPlacesView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.nearbySearch) private var nearbySearch
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements

    @StateObject private var viewModel = NearbyPlacesViewModel()
    @State private var addedIDs: Set<UUID> = []
    @State private var showPaywall = false
    @State private var showMap = false
    @AppStorage("pinly.nearbyRadiusMeters") private var radiusMeters = 1000.0

    private static let radiusOptions: [Double] = [500, 1000, 2000, 5000]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle(NSLocalizedString("Yakınımda", comment: ""))
            .navigationBarTitleDisplayMode(.large)
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
        }
    }
}

// MARK: - Row

private struct NearbyPlaceRow: View {
    let place: NearbyPlace
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(place.category.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: place.category.icon)
                    .font(.callout)
                    .foregroundColor(place.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(place.formattedDistance)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(place.category.color)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundColor(isAdded ? PinlyTheme.success : PinlyTheme.primary)
            }
            .disabled(isAdded)
        }
        .padding(12)
        .background(PinlyTheme.surface)
        .cornerRadius(14)
    }
}
