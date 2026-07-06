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
        case 6..<12:  return NSLocalizedString("Günaydın ☀️", comment: "")
        case 12..<18: return NSLocalizedString("İyi günler 👋", comment: "")
        case 18..<23: return NSLocalizedString("İyi akşamlar 🌆", comment: "")
        default:      return NSLocalizedString("İyi geceler 🌙", comment: "")
        }
    }

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }

    private var recentPlaces: [Place] {
        Array(placeStore.places.sorted { $0.createdAt > $1.createdAt }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Üst başlık
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Ne yapmak istiyorsun?", comment: ""))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    if !locationManager.currentDistrict.isEmpty {
                        Label(locationManager.currentDistrict, systemImage: "location.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(PinlyTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PinlyTheme.primary.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
                .padding(.top, 12)

                // İstatistik şeridi
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
                .pinlyCard()

                // Hero CTA — Rota Planla
                Button {
                    showRoute = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 56, height: 56)
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
                    .background(PinlyTheme.heroGradient)
                    .cornerRadius(20)
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
        .background(PinlyTheme.ground)
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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(place.categoryColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: place.categoryIcon)
                            .font(.subheadline)
                            .foregroundColor(place.categoryColor)
                    }
                    Spacer()
                    if place.isVisited {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(PlaceCategory.from(place.category).localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
