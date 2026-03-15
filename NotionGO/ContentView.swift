import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var placeStore = PlaceStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()

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
                        title: "Mekanlarım",
                        subtitle: placeStore.places.isEmpty
                            ? "Henüz mekan eklenmedi"
                            : "\(placeStore.places.count) mekan kayıtlı",
                        actionLabel: "Görüntüle & Düzenle",
                        backgroundColor: Color.blue.opacity(0.08)
                    ) {
                        showPlaces = true
                    }

                    // Rota Planla Kartı
                    HomeCard(
                        icon: "map.fill",
                        iconColor: .green,
                        title: "Rota Planla",
                        subtitle: "Konumuna göre rota oluştur",
                        actionLabel: "Başla",
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

    var body: some View {
        NavigationStack {
            Group {
                if sortedPlaces.isEmpty {
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
                        Section(header: Text("\(sortedPlaces.count) mekan").textCase(nil)) {
                            ForEach(sortedPlaces) { place in
                                PlaceListItemView(place: place, modelContext: modelContext)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    placeStore.deletePlace(sortedPlaces[index], context: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mekanlarım")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPlace = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPlace) {
                AddPlaceView()
                    .environmentObject(placeStore)
            }
        }
    }
}

// MARK: - Mekan Liste Elemanı

struct PlaceListItemView: View {
    let place: Place
    let modelContext: ModelContext
    @EnvironmentObject var placeStore: PlaceStore

    @State private var showEdit = false

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
                Text(place.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if place.visitCount > 0 {
                    Text("Visited \(place.visitCount) time\(place.visitCount == 1 ? "" : "s")")
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

            VStack(spacing: 8) {
                // Ziyaret edildi butonu
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        place.isVisited.toggle()
                        try? modelContext.save()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(place.isVisited ? .green : .secondary)
                }
                .buttonStyle(.plain)

                // Düzenle butonu
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundColor(.blue.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEdit) {
            EditPlaceView(place: place)
                .environmentObject(placeStore)
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
                Text("Ayarlar > NotionGO > Konum bölümünden izin ver.")
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
