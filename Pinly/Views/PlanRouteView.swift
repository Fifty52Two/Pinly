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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore

    @StateObject private var viewModel: PlanRouteViewModel

    @State private var step: PlanStep = .pickLocation
    @State private var cameraPosition: MapCameraPosition = .automatic

    init(editingRoute: SavedRoute? = nil) {
        _viewModel = StateObject(wrappedValue: PlanRouteViewModel(editingRoute: editingRoute))
    }

    private var sortedPlaces: [Place] { viewModel.sortedPlaces(placeStore.places) }
    private var selectedPlaces: [Place] { viewModel.selectedPlaces(from: placeStore.places) }

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
                        .disabled(viewModel.pinCoordinate == nil)
                    } else if step == .selectPlaces {
                        Button(NSLocalizedString("Devam Et", comment: "")) {
                            step = .nameRoute
                        }
                        .fontWeight(.semibold)
                        .disabled(viewModel.selectedPlaceIDs.isEmpty)
                    }
                }
            }
            .onAppear {
                if let region = viewModel.hydrateIfEditing(places: placeStore.places) {
                    cameraPosition = .region(region)
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
            .alert(NSLocalizedString("Rota Kaydedildi!", comment: ""), isPresented: $viewModel.savedSuccessfully) {
                Button(NSLocalizedString("Tamam", comment: "")) { dismiss() }
            } message: {
                Text(String(format: NSLocalizedString("\"%@\" rotası %lld mekanla kaydedildi.", comment: ""), viewModel.routeName, selectedPlaces.count))
            }
        }
    }

    // MARK: - Adım 1: Konumu Seç

    private var pickLocationStep: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coord = viewModel.pinCoordinate {
                        Annotation("", coordinate: coord, anchor: .bottom) {
                            DroppingPin()
                                .id(viewModel.pinCoordinate?.latitude)
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
                        viewModel.pinCoordinate = coord
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
                    if viewModel.pinCoordinate == nil {
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
                        .foregroundColor(PinlyTheme.success)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(12)
                .animation(.spring(response: 0.3), value: viewModel.pinCoordinate == nil)

                if placeStore.places.isEmpty {
                    Text(NSLocalizedString("Henüz mekan eklenmedi. Önce Mekanlarım'a mekan ekle.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PinlyTheme.warning.opacity(0.12))
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
                Image(systemName: viewModel.selectedPlaceIDs.isEmpty ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(viewModel.selectedPlaceIDs.isEmpty ? .secondary : .blue)
                Text(
                    viewModel.selectedPlaceIDs.isEmpty
                        ? NSLocalizedString("Rotaya eklemek istediğin mekanları seç", comment: "")
                        : String(format: NSLocalizedString("%lld mekan seçildi", comment: ""), viewModel.selectedPlaceIDs.count)
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(viewModel.selectedPlaceIDs.isEmpty ? .secondary : .blue)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .animation(.spring(response: 0.25), value: viewModel.selectedPlaceIDs.count)

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
                            isSelected: viewModel.selectedPlaceIDs.contains(place.id),
                            distanceFromPin: viewModel.distanceFromPin(to: place)
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                if viewModel.selectedPlaceIDs.contains(place.id) {
                                    viewModel.selectedPlaceIDs.remove(place.id)
                                } else {
                                    viewModel.selectedPlaceIDs.insert(place.id)
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
                TextField(NSLocalizedString("Rota adı (örn: Kadıköy Turu)", comment: ""), text: $viewModel.routeName)
                    .submitLabel(.done)
                Picker(NSLocalizedString("Rota Türü", comment: ""), selection: $viewModel.routeCategory) {
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
                    viewModel.saveRoute(places: placeStore.places, context: modelContext)
                } label: {
                    if viewModel.isSaving {
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
                .disabled(viewModel.routeName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
            }
        }
    }

    // MARK: - Yardımcılar

    private var stepTitle: String {
        let isEditing = viewModel.editingRoute != nil
        switch step {
        case .pickLocation: return NSLocalizedString("Rota Merkezi Seç", comment: "")
        case .selectPlaces: return NSLocalizedString("Mekan Seç", comment: "")
        case .nameRoute:    return isEditing
            ? NSLocalizedString("Rotayı Güncelle", comment: "")
            : NSLocalizedString("Rotayı Kaydet", comment: "")
        }
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
                        .fill(isSelected ? PinlyTheme.primary : PinlyTheme.fillMuted)
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
                    .foregroundStyle(.white, PinlyTheme.accent)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2) // bilinçli: canlı harita üzerinde yüzen pin
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
