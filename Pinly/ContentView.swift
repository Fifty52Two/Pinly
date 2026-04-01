import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var placeStore = PlaceStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()

    @State private var pendingImport: PlaceImportData? = nil
    @State private var showImportSheet = false
    @State private var isImporting = false
    @State private var showDeepLinkPaywall = false
    @State private var pendingRouteImport: [PlaceImportData] = []
    @State private var showRouteImportSheet = false

    var body: some View {
        Group {
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
        .onAppear {
            placeStore.load(context: modelContext)
        }
        .onOpenURL { url in
            if let data = PlaceImporter.parse(url: url) {
                pendingImport = data
                showImportSheet = true
            } else if let places = PlaceImporter.parseRoute(url: url) {
                pendingRouteImport = places
                showRouteImportSheet = true
            }
        }
        .sheet(isPresented: $showImportSheet, onDismiss: { pendingImport = nil }) {
            if let data = pendingImport {
                ImportConfirmView(
                    data: data,
                    isSaving: $isImporting,
                    onConfirm: { importPendingPlace(data) },
                    onCancel: { showImportSheet = false }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showRouteImportSheet, onDismiss: { pendingRouteImport = [] }) {
            RouteImportView(
                places: pendingRouteImport,
                onConfirm: { importRoute() },
                onCancel: { showRouteImportSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDeepLinkPaywall) {
            PaywallView { showDeepLinkPaywall = false }
        }
        .alert("Hata", isPresented: Binding(
            get: { placeStore.lastError != nil },
            set: { if !$0 { placeStore.lastError = nil } }
        )) {
            Button("Tamam", role: .cancel) { placeStore.lastError = nil }
        } message: {
            Text(placeStore.lastError ?? "")
        }
    }

    private func importRoute() {
        guard FreemiumManager.canAddPlace(
            currentCount: placeStore.places.count + pendingRouteImport.count - 1
        ) else {
            showRouteImportSheet = false
            showDeepLinkPaywall = true
            return
        }
        let toImport = pendingRouteImport
        showRouteImportSheet = false
        Task {
            for data in toImport {
                await PlaceImporter.save(data, placeStore: placeStore, context: modelContext)
            }
        }
    }

    private func importPendingPlace(_ data: PlaceImportData) {
        guard FreemiumManager.canAddPlace(currentCount: placeStore.places.count) else {
            showImportSheet = false
            showDeepLinkPaywall = true
            return
        }
        isImporting = true
        Task {
            await PlaceImporter.save(data, placeStore: placeStore, context: modelContext)
            await MainActor.run {
                isImporting = false
                showImportSheet = false
            }
        }
    }
}


// MARK: - Ana Ekran

struct HomeView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    @State private var showPlaces = false
    @State private var showRoute = false

    var body: some View {
        ZStack {
            // Arka plan gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // Üst başlık
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Merhaba 👋")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Ne yapmak istiyorsun?")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        // Konum göstergesi
                        if !locationManager.currentDistrict.isEmpty {
                            Label(locationManager.currentDistrict, systemImage: "location.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                }

                // İki ana kart
                VStack(spacing: 16) {

                    // Mekanlarım Kartı
                    HomeCard(
                        icon: "mappin.and.ellipse",
                        iconColor: .blue,
                        title: String(localized: "Mekanlarım"),
                        subtitle: placeStore.places.isEmpty
                            ? String(localized: "Henüz mekan eklenmedi")
                            : String(format: NSLocalizedString("%lld mekan kayıtlı", comment: ""), placeStore.places.count),
                        actionLabel: String(localized: "Görüntüle & Düzenle"),
                        backgroundColor: Color.blue.opacity(0.08)
                    ) {
                        showPlaces = true
                    }

                    // Rota Planla Kartı
                    HomeCard(
                        icon: "map.fill",
                        iconColor: .green,
                        title: String(localized: "Rota Planla"),
                        subtitle: String(localized: "Konumuna göre rota oluştur"),
                        actionLabel: String(localized: "Başla"),
                        backgroundColor: Color.green.opacity(0.08)
                    ) {
                        showRoute = true
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Alt bilgi
                Text("Mekanlarını ekleyip rotanı planla")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showPlaces) {
            PlacesListView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
        .fullScreenCover(isPresented: $showRoute) {
            MapView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
    }
}

// MARK: - Ana Kart Bileşeni

struct HomeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let actionLabel: String
    let backgroundColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 18) {
                // İkon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(iconColor)
                }

                // Metin
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Ok
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(iconColor)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(iconColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: iconColor.opacity(0.18), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mekanlar Listesi

struct PlacesListView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddPlace = false
    @State private var showMap = false
    @State private var showQRScanner = false
    @State private var showPaywall = false
    @State private var searchText = ""
    @State private var selectedCategory: PlaceCategory? = nil

    var sortedPlaces: [Place] {
        guard let userLoc = locationManager.userLocation else {
            return placeStore.places
        }
        return placeStore.places.sorted { a, b in
            guard let coordA = a.coordinate, let coordB = b.coordinate else { return false }
            let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
            let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
            return userLoc.distance(from: locA) < userLoc.distance(from: locB)
        }
    }

    var filteredPlaces: [Place] {
        var result = sortedPlaces
        if let cat = selectedCategory {
            result = result.filter { PlaceCategory.from($0.category) == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.address.lowercased().contains(q)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if placeStore.places.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Henüz mekan eklenmedi")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("+ butonuna basarak mekan ekleyebilirsin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        // Kategori filtre chip'leri
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    CategoryChip(
                                        title: "Tümü",
                                        color: .blue,
                                        isSelected: selectedCategory == nil
                                    ) { selectedCategory = nil }
                                    ForEach(PlaceCategory.allCases, id: \.self) { cat in
                                        CategoryChip(
                                            title: cat.localizedName,
                                            color: cat.color,
                                            isSelected: selectedCategory == cat
                                        ) { selectedCategory = cat }
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
                                    Text("Sonuç bulunamadı")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Button("Filtreleri Temizle") {
                                        searchText = ""
                                        selectedCategory = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
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
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Mekan veya adres ara..."
            )
            .navigationTitle("Mekanlarım")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        Button {
                            showQRScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                        Button {
                            if FreemiumManager.canAddPlace(currentCount: placeStore.places.count) {
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
        }
    }
}

// MARK: - Mekan Liste Elemanı

struct PlaceListItemView: View {
    let place: Place
    let modelContext: ModelContext
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager

    @State private var showEdit = false
    @State private var showShare = false

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
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(place.isVisited ? .secondary : .primary)
                    .strikethrough(place.isVisited, color: .secondary)
                Text(PlaceCategory.from(place.category).localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if place.visitCount > 0 {
                    Text("\(place.visitCount)x ziyaret")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                if let rating = place.userRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundColor(star <= rating ? .yellow : .secondary)
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
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { showEdit = true }
        // Sola kaydır: Paylaş + Sil
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                placeStore.deletePlace(place, context: modelContext)
            } label: {
                Label("Sil", systemImage: "trash")
            }
            Button {
                showShare = true
            } label: {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
            .tint(.orange)
        }
        // Sağa kaydır: Ziyaret toggle
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                place.isVisited.toggle()
                if place.isVisited { place.visitCount += 1 }
                placeStore.save(context: modelContext)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label(
                    place.isVisited ? "Ziyaret Edilmedi" : "Ziyaret Edildi",
                    systemImage: place.isVisited ? "xmark.circle" : "checkmark.circle"
                )
            }
            .tint(place.isVisited ? .gray : .green)
        }
        .sheet(isPresented: $showEdit) {
            EditPlaceView(place: place)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showShare) {
            SharePlaceView(place: place)
        }
    }
}

// MARK: - İzin Bekleniyor

struct PermissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            VStack(spacing: 8) {
                Text("Konumuna İhtiyacımız Var")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Bulunduğun semtteki mekanları göstermek için konum izni gerekiyor.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
    }
}

// MARK: - Rota Import View

private struct RouteImportView: View {
    let places: [PlaceImportData]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding(.top, 24)

                Text("\(places.count) Duraklı Rota Paylaşıldı")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Tüm mekanları listenize eklemek ister misiniz?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Mekan listesi
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PlaceCategory.from(place.category).color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: PlaceCategory.from(place.category).icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(PlaceCategory.from(place.category).color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(PlaceCategory.from(place.category).localizedName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        if index < places.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            Spacer()

            // Butonlar
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("Tümünü Ekle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(14)
                }
                Button(action: onCancel) {
                    Text("İptal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
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

// MARK: - İzin Reddedildi

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            VStack(spacing: 8) {
                Text("Konum İzni Gerekli")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Ayarlar > Pinly > Konum bölümünden izin ver.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Ayarlara Git")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }
}
