import SwiftUI

// MARK: - Ana Sekme

struct MainTab: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.entitlements) private var entitlements
    @Environment(\.badges) private var badges

    @State private var showPlaces = false
    @State private var showRoute = false
    @State private var showAddPlace = false
    @State private var showQRScanner = false
    @State private var showPlanRoute = false
    @State private var showPaywall = false
    @State private var detailPlace: Place? = nil

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 6..<12:  return NSLocalizedString("Günaydın,", comment: "")
        case 12..<18: return NSLocalizedString("İyi günler,", comment: "")
        case 18..<23: return NSLocalizedString("İyi akşamlar,", comment: "")
        default:      return NSLocalizedString("İyi geceler,", comment: "")
        }
    }

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }

    private var recentPlaces: [Place] {
        Array(placeStore.places.sorted { $0.createdAt > $1.createdAt }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Üst başlık — sağda ufak gezgin illüstrasyonu (aksan)
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Ne yapmak istiyorsun?", comment: ""))
                            .font(.title)
                            .fontWeight(.bold)
                        if !locationManager.currentDistrict.isEmpty {
                            Label(locationManager.currentDistrict, systemImage: "location.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(PinlyTheme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(PinlyTheme.primary.opacity(0.1))
                                .cornerRadius(20)
                                .padding(.top, 4)
                        }
                    }
                    Spacer(minLength: 0)
                    Image("illus_walk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                }
                .padding(.top, 12)

                // İstatistik şeridi — arkasında filigran illüstrasyon
                HStack(spacing: 0) {
                    StatChip(value: "\(placeStore.places.count)",
                             label: NSLocalizedString("Mekan", comment: ""),
                             icon: "mappin.circle.fill", color: PinlyTheme.primary)
                    StatChip(value: "\(visitedCount)",
                             label: NSLocalizedString("Ziyaret", comment: ""),
                             icon: "checkmark.circle.fill", color: PinlyTheme.primaryWarm)
                    StatChip(value: "\(badges.consecutiveDays)",
                             label: NSLocalizedString("Gün Serisi", comment: ""),
                             icon: "flame.fill", color: PinlyTheme.accent)
                    StatChip(value: "\(badges.unlockedBadges.count)",
                             label: NSLocalizedString("Rozet", comment: ""),
                             icon: "trophy.fill", color: PinlyTheme.gold)
                }
                .padding(16)
                .background(
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PinlyTheme.surface)
                        Image("illus_camping")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150)
                            .opacity(0.07)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }
                )

                // Hero CTA — Rota Planla
                Button {
                    showRoute = true
                } label: {
                    ZStack(alignment: .trailing) {
                        // Arka plan gradyan
                        RoundedRectangle(cornerRadius: 20)
                            .fill(PinlyTheme.heroGradient)

                        // Sağda kayan illüstrasyon
                        Image("illus_bike")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 110)
                            .opacity(0.22)
                            .offset(x: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        // Sol taraf metin + ikon
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "map.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(NSLocalizedString("Rota Planla", comment: ""))
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                Text(NSLocalizedString("Konumuna göre rota oluştur", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(20)
                    }
                    .frame(height: 100)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)

                // Hızlı aksiyonlar
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickActionCard(icon: "mappin.and.ellipse", color: PinlyTheme.primary,
                                    title: NSLocalizedString("Mekanlarım", comment: ""),
                                    subtitle: String(format: NSLocalizedString("%lld mekan kayıtlı", comment: ""), placeStore.places.count)) {
                        showPlaces = true
                    }
                    QuickActionCard(icon: "plus.circle.fill", color: PinlyTheme.primaryWarm,
                                    title: NSLocalizedString("Mekan Ekle", comment: ""),
                                    subtitle: NSLocalizedString("Yeni bir yer kaydet", comment: "")) {
                        if entitlements.canAddPlace(currentCount: placeStore.places.count) {
                            showAddPlace = true
                        } else {
                            showPaywall = true
                        }
                    }
                    QuickActionCard(icon: "qrcode.viewfinder", color: PinlyTheme.slate,
                                    title: NSLocalizedString("QR Tara", comment: ""),
                                    subtitle: NSLocalizedString("Paylaşılan mekanı al", comment: "")) {
                        showQRScanner = true
                    }
                    QuickActionCard(icon: "bookmark.fill", color: PinlyTheme.gold,
                                    title: NSLocalizedString("Rota Tasarla", comment: ""),
                                    subtitle: NSLocalizedString("Sonrası için planla", comment: "")) {
                        showPlanRoute = true
                    }
                }

                // Son eklenenler
                if !recentPlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("Son Eklenenler", comment: ""))
                                .font(.headline)
                            Spacer()
                            Button(NSLocalizedString("Tümü", comment: "")) {
                                showPlaces = true
                            }
                            .font(.subheadline)
                            .foregroundColor(PinlyTheme.primary)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recentPlaces) { place in
                                    RecentPlaceCard(place: place) {
                                        detailPlace = place
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(PinlyTheme.groundGradient)
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
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView()
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showPlanRoute) {
            PlanRouteView()
                .environmentObject(locationManager)
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
        .sheet(item: $detailPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
            }
        }
    }
}

// MARK: - Hızlı Aksiyon Kartı

private struct QuickActionCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Son Eklenen Mekan Kartı

private struct RecentPlaceCard: View {
    let place: Place
    let onTap: () -> Void

    private var category: PlaceCategory { PlaceCategory.from(place.category) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Üst: illüstrasyon
                ZStack(alignment: .topTrailing) {
                    Image(category.illustrationName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 110)
                        .clipped()
                        .background(category.color.opacity(0.08))

                    if place.isVisited {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .padding(8)
                    }
                }

                // Alt: metin
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.caption2)
                            .foregroundColor(category.color)
                        Text(category.localizedName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PinlyTheme.surface)
            }
            .frame(width: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
