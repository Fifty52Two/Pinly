import SwiftUI
import SwiftData
import CoreLocation
import UniformTypeIdentifiers

// MARK: - Sort Option

enum PlaceSortOption: String, CaseIterable {
    case dateAdded = "dateAdded"
    case alphabetical = "alphabetical"
    case distance = "distance"
    case visitCount = "visitCount"

    var localizedName: String {
        switch self {
        case .dateAdded:    return NSLocalizedString("Eklenme Tarihi", comment: "")
        case .alphabetical: return NSLocalizedString("Alfabetik", comment: "")
        case .distance:     return NSLocalizedString("Mesafe", comment: "")
        case .visitCount:   return NSLocalizedString("Ziyaret Sayısı", comment: "")
        }
    }
}

// MARK: - Mekanlar Listesi

struct PlacesListView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.entitlements) private var entitlements
    @Environment(\.swarmImporting) private var swarmImporting

    @StateObject private var viewModel = PlacesListViewModel()

    @State private var showAddPlace = false
    @State private var showMap = false
    @State private var showQRScanner = false
    @State private var showPaywall = false
    @State private var showSwarmPicker = false
    @State private var pendingSwarmPlaces: [PlaceImportData] = []
    @State private var showSwarmImport = false
    @State private var swarmParseError = false

    // Toplu silme (edit modu)
    @State private var editMode: EditMode = .inactive
    @State private var selectedIDs = Set<UUID>()
    @State private var showBulkDeleteConfirm = false

    var filteredPlaces: [Place] {
        viewModel.filteredPlaces(placeStore.places, userLocation: locationManager.userLocation)
    }

    var body: some View {
        NavigationStack {
            Group {
                if placeStore.places.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Henüz mekan eklenmedi", comment: ""))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(NSLocalizedString("+ butonuna basarak mekan ekleyebilirsin", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(selection: $selectedIDs) {
                        // Kategori filtre chip'leri
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    CategoryChip(
                                        title: NSLocalizedString("Tümü", comment: ""),
                                        color: PinlyTheme.primary,
                                        isSelected: viewModel.selectedCategory == nil
                                    ) { viewModel.selectedCategory = nil }
                                    ForEach(PlaceCategory.allCases, id: \.self) { cat in
                                        CategoryChip(
                                            title: cat.localizedName,
                                            color: cat.color,
                                            isSelected: viewModel.selectedCategory == cat
                                        ) { viewModel.selectedCategory = cat }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listSectionSeparator(.hidden)

                        // Sonuçlar
                        if filteredPlaces.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                    Text(NSLocalizedString("Sonuç bulunamadı", comment: ""))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Button(NSLocalizedString("Filtreleri Temizle", comment: "")) {
                                        viewModel.clearFilters()
                                    }
                                    .font(.caption)
                                    .foregroundColor(PinlyTheme.primary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                            .listSectionSeparator(.hidden)
                        } else {
                            Section(header: Text(String(format: NSLocalizedString("%lld mekan kayıtlı", comment: ""), filteredPlaces.count)).textCase(nil)) {
                                ForEach(filteredPlaces) { place in
                                    PlaceListItemView(place: place, modelContext: modelContext)
                                        .tag(place.id)
                                }
                            }
                            .listRowBackground(PinlyTheme.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PinlyTheme.groundGradient)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: NSLocalizedString("Mekan veya adres ara...", comment: "")
            )
            .navigationTitle(NSLocalizedString("Mekanlarım", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if editMode.isEditing {
                        Button(NSLocalizedString("Vazgeç", comment: "")) {
                            editMode = .inactive
                            selectedIDs.removeAll()
                        }
                    } else {
                        Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if editMode.isEditing {
                        Button(role: .destructive) {
                            showBulkDeleteConfirm = true
                        } label: {
                            Text(String(format: NSLocalizedString("Sil (%lld)", comment: ""), selectedIDs.count))
                                .fontWeight(.semibold)
                        }
                        .disabled(selectedIDs.isEmpty)
                    } else {
                        HStack(spacing: 4) {
                            Menu {
                                ForEach(PlaceSortOption.allCases, id: \.self) { option in
                                    Button {
                                        viewModel.setSortOption(option)
                                    } label: {
                                        if viewModel.sortOption == option {
                                            Label(option.localizedName, systemImage: "checkmark")
                                        } else {
                                            Text(option.localizedName)
                                        }
                                    }
                                }
                                Divider()
                                Button {
                                    editMode = .active
                                } label: {
                                    Label(NSLocalizedString("Mekanları Seç", comment: ""), systemImage: "checkmark.circle")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            Button {
                                showSwarmPicker = true
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Button {
                                showQRScanner = true
                            } label: {
                                Image(systemName: "qrcode.viewfinder")
                            }
                            Button {
                                if entitlements.canAddPlace(currentCount: placeStore.places.count) {
                                    showAddPlace = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .confirmationDialog(
                String(format: NSLocalizedString("%lld mekan silinsin mi?", comment: ""), selectedIDs.count),
                isPresented: $showBulkDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("Sil", comment: ""), role: .destructive) {
                    deleteSelectedPlaces()
                }
                Button(NSLocalizedString("Vazgeç", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Bu işlem geri alınamaz. Fotoğraflar da silinir.", comment: ""))
            }
            .sheet(isPresented: $showAddPlace) {
                AddPlaceView()
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView()
                    .environmentObject(placeStore)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
            .sheet(isPresented: $showSwarmImport) {
                SwarmImportView(
                    places: pendingSwarmPlaces,
                    currentCount: placeStore.places.count,
                    onConfirm: { importSwarm() },
                    onCancel: { showSwarmImport = false }
                )
                .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showSwarmPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                guard let url = try? result.get().first,
                      url.startAccessingSecurityScopedResource()
                else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url),
                      let places = swarmImporting.parseSwarm(data: data)
                else { swarmParseError = true; return }
                pendingSwarmPlaces = places
                showSwarmImport = true
            }
            .alert(NSLocalizedString("Dosya Okunamadı", comment: ""), isPresented: $swarmParseError) {
                Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Geçerli bir Swarm checkins.json dosyası seçin.", comment: ""))
            }
        }
    }

    private func deleteSelectedPlaces() {
        for place in placeStore.places where selectedIDs.contains(place.id) {
            placeStore.deletePlace(place, context: modelContext)
        }
        selectedIDs.removeAll()
        editMode = .inactive
    }

    private func importSwarm() {
        guard entitlements.canAddPlace(
            currentCount: placeStore.places.count + pendingSwarmPlaces.count - 1
        ) else {
            showSwarmImport = false
            showPaywall = true
            return
        }
        let toImport = pendingSwarmPlaces
        showSwarmImport = false
        pendingSwarmPlaces = []
        Task {
            for data in toImport {
                await placeStore.importPlace(data, context: modelContext)
            }
        }
    }
}

// MARK: - Mekan Liste Elemanı

struct PlaceListItemView: View {
    let place: Place
    let modelContext: ModelContext
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.placePhotos) private var placePhotos
    @Environment(\.editMode) private var editMode

    @State private var showDetail = false
    @State private var showShare = false
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        HStack(spacing: 14) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(place.categoryColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: place.categoryIcon)
                        .foregroundColor(place.categoryColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(place.isVisited ? .secondary : .primary)
                    .strikethrough(place.isVisited, color: .secondary)
                Text(PlaceCategory.from(place.category).localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if place.visitCount > 0 {
                    Text(String(format: NSLocalizedString("%ldx ziyaret", comment: ""), place.visitCount))
                        .font(.caption2)
                        .foregroundColor(PinlyTheme.success)
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
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Ziyaret göstergesi (sadece görsel, interactive değil)
            if place.isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PinlyTheme.success)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // simultaneousGesture: edit modunda List'in seçim dokunuşunu bloklamaz
        .simultaneousGesture(TapGesture().onEnded {
            guard editMode?.wrappedValue.isEditing != true else { return }
            showDetail = true
        })
        .onAppear { reloadThumbnail() }
        .onChange(of: place.photoFileName) { reloadThumbnail() }
        // Sola kaydır: Paylaş + Sil
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                placeStore.deletePlace(place, context: modelContext)
            } label: {
                Label(NSLocalizedString("Sil", comment: ""), systemImage: "trash")
            }
            Button {
                showShare = true
            } label: {
                Label(NSLocalizedString("Paylaş", comment: ""), systemImage: "square.and.arrow.up")
            }
            .tint(PinlyTheme.warning)
        }
        // Sağa kaydır: Ziyaret toggle
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                place.isVisited.toggle()
                if place.isVisited { place.visitCount += 1 }
                placeStore.save(context: modelContext)
                placeStore.refreshBadges()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label(
                    place.isVisited ? NSLocalizedString("Ziyaret Edilmedi", comment: "") : NSLocalizedString("Ziyaret Edildi", comment: ""),
                    systemImage: place.isVisited ? "xmark.circle" : "checkmark.circle"
                )
            }
            .tint(place.isVisited ? Color.gray : PinlyTheme.success)
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                PlaceDetailView(place: place)
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
            }
        }
        .sheet(isPresented: $showShare) {
            SharePlaceView(place: place)
        }
    }

    private func reloadThumbnail() {
        thumbnail = place.photoFileName.flatMap { placePhotos.load(fileName: $0) }
    }
}

// MARK: - Kategori Chip

private struct CategoryChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.12))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
