import SwiftUI
import MapKit
import SwiftData
import CoreLocation

// MARK: - Adım enum

private enum PlanStep {
    case pickLocation   // Haritada pin bırak
    case selectPlaces   // Kayıtlı mekanları seç
    case nameRoute      // Rota adı + kategori
}

// MARK: - PlanRouteView

struct PlanRouteView: View {
    var editingRoute: SavedRoute? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.badges) private var badgeService

    @State private var step: PlanStep = .pickLocation
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPlaceIDs: Set<UUID> = []
    @State private var routeName = ""
    @State private var routeCategory: RouteCategory = .city
    @State private var isSaving = false
    @State private var savedSuccessfully = false

    // Mekanları pin'e mesafeye göre sıralar
    private var sortedPlaces: [Place] {
        guard let pin = pinCoordinate else { return placeStore.places }
        let pinLoc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        return placeStore.places.sorted { a, b in
            let distA = a.coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: pinLoc) } ?? Double.infinity
            let distB = b.coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: pinLoc) } ?? Double.infinity
            return distA < distB
        }
    }

    private var selectedPlaces: [Place] {
        sortedPlaces.filter { selectedPlaceIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch step {
                case .pickLocation:
                    pickLocationStep
                case .selectPlaces:
                    selectPlacesStep
                case .nameRoute:
                    nameRouteStep
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("İptal", comment: "")) {
                        switch step {
                        case .pickLocation: dismiss()
                        case .selectPlaces: step = .pickLocation
                        case .nameRoute:    step = .selectPlaces
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if step == .pickLocation {
                        Button(NSLocalizedString("Devam Et", comment: "")) {
                            step = .selectPlaces
                        }
                        .fontWeight(.semibold)
                        .disabled(pinCoordinate == nil)
                    } else if step == .selectPlaces {
                        Button(NSLocalizedString("Devam Et", comment: "")) {
                            step = .nameRoute
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedPlaceIDs.isEmpty)
                    }
                }
            }
            .onAppear {
                if let route = editingRoute {
                    // Edit modu: rota verilerini doldur
                    let center = CLLocationCoordinate2D(
                        latitude: route.centerLatitude,
                        longitude: route.centerLongitude
                    )
                    pinCoordinate = center
                    cameraPosition = .region(MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                    routeName = route.name
                    if let catRaw = route.categoryRaw, let cat = RouteCategory(rawValue: catRaw) {
                        routeCategory = cat
                    }
                    // Snapshot isimlerine göre mevcut mekanları eşleştir
                    let snapNames = Set(route.placeSnapshots.map { $0.name })
                    let matched = placeStore.places.filter { snapNames.contains($0.name) }
                    selectedPlaceIDs = Set(matched.map { $0.id })
                    step = .selectPlaces
                } else if let userLoc = locationManager.userLocation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLoc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                } else {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
            .alert(NSLocalizedString("Rota Kaydedildi!", comment: ""), isPresented: $savedSuccessfully) {
                Button(NSLocalizedString("Tamam", comment: "")) { dismiss() }
            } message: {
                Text(String(format: NSLocalizedString("\"%@\" rotası %lld mekanla kaydedildi.", comment: ""), routeName, selectedPlaces.count))
            }
        }
    }

    // MARK: - Adım 1: Konumu Seç

    private var pickLocationStep: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coord = pinCoordinate {
                        Annotation("", coordinate: coord, anchor: .bottom) {
                            DroppingPin()
                                .id(pinCoordinate?.latitude)
                        }
                    }
                    // Kayıtlı mekanları haritada göster
                    ForEach(placeStore.places) { place in
                        if let coord = place.coordinate {
                            Annotation(place.name, coordinate: coord, anchor: .bottom) {
                                Image(systemName: place.placeCategory.icon)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(place.placeCategory.color)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    UserAnnotation()
                }
                .onTapGesture { screenPoint in
                    guard let coord = proxy.convert(screenPoint, from: .local) else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        pinCoordinate = coord
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            // Alt bilgi
            VStack(spacing: 8) {
                Group {
                    if pinCoordinate == nil {
                        Label(
                            NSLocalizedString("Rota merkezi için haritaya dokun", comment: ""),
                            systemImage: "hand.tap.fill"
                        )
                        .foregroundColor(.secondary)
                    } else {
                        Label(
                            NSLocalizedString("Konum seçildi — devam edebilirsin", comment: ""),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundColor(.green)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(12)
                .animation(.spring(response: 0.3), value: pinCoordinate == nil)

                if placeStore.places.isEmpty {
                    Text(NSLocalizedString("Henüz mekan eklenmedi. Önce Mekanlarım'a mekan ekle.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Adım 2: Mekan Seç

    private var selectPlacesStep: some View {
        VStack(spacing: 0) {
            // Seçim özeti
            HStack {
                Image(systemName: selectedPlaceIDs.isEmpty ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(selectedPlaceIDs.isEmpty ? .secondary : .blue)
                Text(
                    selectedPlaceIDs.isEmpty
                        ? NSLocalizedString("Rotaya eklemek istediğin mekanları seç", comment: "")
                        : String(format: NSLocalizedString("%lld mekan seçildi", comment: ""), selectedPlaceIDs.count)
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(selectedPlaceIDs.isEmpty ? .secondary : .blue)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .animation(.spring(response: 0.25), value: selectedPlaceIDs.count)

            if sortedPlaces.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("Henüz mekan yok", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("Mekanlarım ekranından mekan ekledikten sonra burada görünür", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedPlaces) { place in
                        PlacePlanRow(
                            place: place,
                            isSelected: selectedPlaceIDs.contains(place.id),
                            distanceFromPin: distanceFromPin(place)
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                if selectedPlaceIDs.contains(place.id) {
                                    selectedPlaceIDs.remove(place.id)
                                } else {
                                    selectedPlaceIDs.insert(place.id)
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Adım 3: Rota Adını Gir

    private var nameRouteStep: some View {
        Form {
            Section {
                TextField(NSLocalizedString("Rota adı (örn: Kadıköy Turu)", comment: ""), text: $routeName)
                    .submitLabel(.done)
                Picker(NSLocalizedString("Rota Türü", comment: ""), selection: $routeCategory) {
                    ForEach(RouteCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
            } header: {
                Text(NSLocalizedString("Rota Bilgileri", comment: ""))
            }

            Section {
                ForEach(selectedPlaces) { place in
                    HStack(spacing: 10) {
                        Image(systemName: place.placeCategory.icon)
                            .foregroundColor(place.placeCategory.color)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name).font(.subheadline).fontWeight(.medium)
                            if !place.address.isEmpty {
                                Text(place.address).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(String(format: NSLocalizedString("%lld mekan seçildi", comment: ""), selectedPlaces.count))
            }

            Section {
                Button {
                    saveRoute()
                } label: {
                    if isSaving {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text(NSLocalizedString("Kaydediliyor...", comment: ""))
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("Rotayı Kaydet", comment: ""))
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(routeName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
    }

    // MARK: - Yardımcılar

    private var stepTitle: String {
        let isEditing = editingRoute != nil
        switch step {
        case .pickLocation: return NSLocalizedString("Rota Merkezi Seç", comment: "")
        case .selectPlaces: return NSLocalizedString("Mekan Seç", comment: "")
        case .nameRoute:    return isEditing
            ? NSLocalizedString("Rotayı Güncelle", comment: "")
            : NSLocalizedString("Rotayı Kaydet", comment: "")
        }
    }

    private func distanceFromPin(_ place: Place) -> String? {
        guard let pin = pinCoordinate, let coord = place.coordinate else { return nil }
        let dist = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        return dist < 1000
            ? String(format: "%.0f m", dist)
            : String(format: "%.1f km", dist / 1000)
    }

    private func saveRoute() {
        let name = routeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !selectedPlaces.isEmpty else { return }
        guard let pin = pinCoordinate else { return }
        isSaving = true

        let snapshots = selectedPlaces.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category,
                address: place.address,
                notes: place.notes,
                latitude: place.coordinate?.latitude ?? pin.latitude,
                longitude: place.coordinate?.longitude ?? pin.longitude,
                sortIndex: index
            )
        }

        if let existing = editingRoute {
            // Edit modu: mevcut rotayı güncelle
            existing.name = name
            existing.categoryRaw = routeCategory.rawValue
            existing.centerLatitude = pin.latitude
            existing.centerLongitude = pin.longitude
            existing.orderedPlaceSnapshotsData = (try? JSONEncoder().encode(snapshots)) ?? Data()
        } else {
            // Yeni rota oluştur
            let route = SavedRoute(
                name: name,
                categoryRaw: routeCategory.rawValue,
                centerLatitude: pin.latitude,
                centerLongitude: pin.longitude,
                snapshots: snapshots
            )
            modelContext.insert(route)
            badgeService.recordSavedRoute()
        }
        try? modelContext.save()

        isSaving = false
        savedSuccessfully = true
    }
}

// MARK: - PlacePlanRow

private struct PlacePlanRow: View {
    let place: Place
    let isSelected: Bool
    let distanceFromPin: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Seçim indikatörü
                ZStack {
                    Circle()
                        .fill(isSelected ? PinlyTheme.primary : Color(.systemGray5))
                        .frame(width: 32, height: 32)
                    Image(systemName: isSelected ? "checkmark" : place.placeCategory.icon)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                .animation(.spring(response: 0.25), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Text(place.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let dist = distanceFromPin {
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))
                                .font(.caption)
                            Text(dist)
                                .font(.caption)
                                .foregroundColor(PinlyTheme.primary)
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? PinlyTheme.primary.opacity(0.07) : Color(.secondarySystemBackground))
                    .animation(.spring(response: 0.25), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DroppingPin

private struct DroppingPin: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 20, height: 6)
                    .offset(y: appeared ? 22 : 14)
                    .scaleEffect(appeared ? 1 : 0.5)

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white, Color.red)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(y: appeared ? 0 : -20)
                    .scaleEffect(appeared ? 1 : 0.7)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}
