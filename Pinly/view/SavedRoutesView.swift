import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct SavedRoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.badges) private var badgeService

    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var savedRoutes: [SavedRoute]

    @State private var showPlanRoute = false
    @State private var showDistanceAlert = false
    @State private var pendingRoute: SavedRoute? = nil
    @State private var distanceText = ""
    @State private var routeToDelete: SavedRoute? = nil
    @State private var showDeleteAlert = false
    @State private var showRouteSummary = false
    @State private var routeToEdit: SavedRoute? = nil
    @State private var showEditRoute = false

    var body: some View {
        NavigationStack {
            Group {
                if savedRoutes.isEmpty {
                    emptyState
                } else {
                    routeList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Kayıtlı Rotalar", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPlanRoute = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showPlanRoute) {
                PlanRouteView()
                    .environmentObject(locationManager)
                    .environmentObject(placeStore)
            }
            .sheet(isPresented: $showEditRoute, onDismiss: { routeToEdit = nil }) {
                if let route = routeToEdit {
                    PlanRouteView(editingRoute: route)
                        .environmentObject(locationManager)
                        .environmentObject(placeStore)
                }
            }
            .fullScreenCover(isPresented: $showRouteSummary) {
                NavigationStack {
                    RouteSummaryView()
                        .environmentObject(routeManager)
                        .environmentObject(locationManager)
                        .environment(\.dismissRouteFlow, { showRouteSummary = false })
                }
            }
            .alert(NSLocalizedString("Başlangıç Noktası Uzakta", comment: ""), isPresented: $showDistanceAlert) {
                Button(NSLocalizedString("Yine de Başlat", comment: ""), role: .destructive) {
                    if let route = pendingRoute {
                        loadAndStart(route)
                        pendingRoute = nil
                    }
                }
                Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {
                    pendingRoute = nil
                }
            } message: {
                Text(distanceText)
            }
            .alert(NSLocalizedString("Rotayı Sil", comment: ""), isPresented: $showDeleteAlert) {
                Button(NSLocalizedString("Sil", comment: ""), role: .destructive) {
                    if let route = routeToDelete {
                        SavedRouteManager.delete(route, context: modelContext)
                        routeToDelete = nil
                    }
                }
                Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {
                    routeToDelete = nil
                }
            } message: {
                if let route = routeToDelete {
                    Text(String(format: NSLocalizedString("\"%@\" rotasını silmek istiyor musun?", comment: ""), route.name))
                }
            }
        }
    }

    // MARK: - Boş durum

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("Henüz kayıtlı rota yok", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
            Text(NSLocalizedString("Önceden bir rota planla, istediğin zaman başlat", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showPlanRoute = true
            } label: {
                Label(NSLocalizedString("Rota Planla", comment: ""), systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PinlyTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Liste

    private var routeList: some View {
        List {
            ForEach(savedRoutes) { route in
                SavedRouteCard(
                    route: route,
                    distanceKm: SavedRouteManager.distanceKm(from: locationManager.userLocation, to: route)
                ) {
                    handleStartRoute(route)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        routeToDelete = route
                        showDeleteAlert = true
                    } label: {
                        Label(NSLocalizedString("Sil", comment: ""), systemImage: "trash")
                    }
                    Button {
                        routeToEdit = route
                        showEditRoute = true
                    } label: {
                        Label(NSLocalizedString("Düzenle", comment: ""), systemImage: "pencil")
                    }
                    .tint(PinlyTheme.primary)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Rota başlatma mantığı

    private func handleStartRoute(_ route: SavedRoute) {
        if let dist = SavedRouteManager.distanceKm(from: locationManager.userLocation, to: route),
           dist > 1 {
            let formatted = dist >= 10
                ? String(format: "%.0f km", dist)
                : String(format: "%.1f km", dist)
            distanceText = String(
                format: NSLocalizedString(
                    "Rotanın başlangıç noktasına yaklaşık %@ uzaktasınız. Yine de başlatmak istiyor musunuz?",
                    comment: ""
                ),
                formatted
            )
            pendingRoute = route
            showDistanceAlert = true
        } else {
            loadAndStart(route)
        }
    }

    private func loadAndStart(_ route: SavedRoute) {
        let snapshots = route.placeSnapshots.sorted { $0.sortIndex < $1.sortIndex }

        var places: [Place] = []
        for snap in snapshots {
            // Önce SwiftData'dan isim ile eşleştirmeyi dene
            let descriptor = FetchDescriptor<Place>(
                predicate: #Predicate { place in place.name == snap.name }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                places.append(existing)
            } else {
                // Geçici yer tutucu — koordinatları ayarla
                let temp = Place(
                    name: snap.name,
                    category: snap.category,
                    address: snap.address,
                    notes: snap.notes
                )
                temp.latitude = snap.latitude
                temp.longitude = snap.longitude
                places.append(temp)
            }
        }

        routeManager.setRoute(places: places, name: route.name)

        badgeService.recordRouteStarted()
        showRouteSummary = true
    }
}

// MARK: - SavedRouteCard

private struct SavedRouteCard: View {
    let route: SavedRoute
    let distanceKm: Double?
    let onStart: () -> Void

    private var mapRegion: MKCoordinateRegion? {
        let coords = route.placeSnapshots.compactMap { snap -> CLLocationCoordinate2D? in
            CLLocationCoordinate2D(latitude: snap.latitude, longitude: snap.longitude)
        }
        guard !coords.isEmpty else { return nil }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Küçük harita thumbnail
            if let region = mapRegion {
                Map(initialPosition: .region(region)) {
                    ForEach(route.placeSnapshots, id: \.sortIndex) { snap in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: snap.latitude, longitude: snap.longitude), anchor: .bottom) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, PinlyTheme.primary)
                        }
                    }
                }
                .mapStyle(.standard(emphasis: .muted))
                .allowsHitTesting(false)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Başlık satırı
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let catRaw = route.categoryRaw,
                       let cat = RouteCategory(rawValue: catRaw) {
                        Label(cat.rawValue, systemImage: cat.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(route.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Mekan sayısı + uzaklık
            HStack(spacing: 16) {
                Label(
                    String(format: NSLocalizedString("%lld mekan", comment: ""), route.placeCount),
                    systemImage: "mappin.circle.fill"
                )
                .font(.caption)
                .foregroundColor(PinlyTheme.primary)

                if let km = distanceKm {
                    Label(distanceLabel(km: km), systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(km > 5 ? .orange : .green)
                }

                Spacer()
            }

            // Mekan isimleri (ilk 3)
            let snaps = route.placeSnapshots.prefix(3)
            let names = snaps.map(\.name)
            if !names.isEmpty {
                let suffix = route.placeCount > 3 ? " +\(route.placeCount - 3)" : ""
                Text(names.joined(separator: " → ") + suffix)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Başlat butonu
            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(NSLocalizedString("Rotayı Başlat", comment: ""))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(PinlyTheme.primary)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(PinlyTheme.surface)
        .cornerRadius(16)
    }

    private func distanceLabel(km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f m uzakta", km * 1000)
        } else if km < 10 {
            return String(format: "%.1f km uzakta", km)
        } else {
            return String(format: "%.0f km uzakta", km)
        }
    }
}
