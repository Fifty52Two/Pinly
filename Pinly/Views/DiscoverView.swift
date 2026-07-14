import SwiftUI

// MARK: - Discover (Keşfet) Ekranı

struct DiscoverView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var categoriesWithPlaces: [(PlaceCategory, [Place])] {
        PlaceCategory.allCases.compactMap { cat in
            let places = placeStore.places.filter { PlaceCategory.from($0.category) == cat }
            return places.isEmpty ? nil : (cat, places)
        }
    }

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }

    var body: some View {
        NavigationStack {
            Group {
                if placeStore.places.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Henüz mekan yok", comment: ""))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(NSLocalizedString("Mekanlarım ekranından mekan ekledikten sonra burada kategorilere göre görebilirsin.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            statsBar
                            nearbyCard
                            categoryGrid
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Keşfet", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            DiscoverStatPill(value: "\(placeStore.places.count)", label: NSLocalizedString("Mekan", comment: ""))
            Divider().frame(height: 32)
            DiscoverStatPill(value: "\(visitedCount)", label: NSLocalizedString("Ziyaret", comment: ""))
            Divider().frame(height: 32)
            DiscoverStatPill(value: "\(categoriesWithPlaces.count)", label: NSLocalizedString("Kategori", comment: ""))
        }
        .padding(.vertical, 14)
        .background(PinlyTheme.surface)
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }

    private var nearbyCard: some View {
        NavigationLink {
            NearbyPlacesView()
                .environmentObject(locationManager)
                .environmentObject(placeStore)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PinlyTheme.primary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "location.magnifyingglass")
                        .font(.title3)
                        .foregroundColor(PinlyTheme.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("Yakınımda", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(NSLocalizedString("Çevrendeki mekanları keşfet ve ekle", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(PinlyTheme.surface)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(categoriesWithPlaces, id: \.0.rawValue) { cat, places in
                NavigationLink {
                    CategoryPlacesView(category: cat, places: places)
                } label: {
                    CategoryDiscoverCard(category: cat, count: places.count)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Kategori Kart

private struct CategoryDiscoverCard: View {
    let category: PlaceCategory
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(category.color)
            }
            Text(category.localizedName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(String(format: NSLocalizedString("%lld mekan", comment: ""), count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PinlyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(category.color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Kategori Detay Listesi

struct CategoryPlacesView: View {
    let category: PlaceCategory
    let places: [Place]

    private var visitedPlaces: [Place] { places.filter { $0.isVisited } }
    private var unvisitedPlaces: [Place] { places.filter { !$0.isVisited } }

    var body: some View {
        List {
            if !unvisitedPlaces.isEmpty {
                Section("\(NSLocalizedString("Gidilecek", comment: "")) (\(unvisitedPlaces.count))") {
                    ForEach(unvisitedPlaces, id: \.id) { place in
                        CategoryPlaceRow(place: place, category: category)
                    }
                }
            }
            if !visitedPlaces.isEmpty {
                Section("\(NSLocalizedString("Ziyaret Edildi", comment: "")) (\(visitedPlaces.count))") {
                    ForEach(visitedPlaces, id: \.id) { place in
                        CategoryPlaceRow(place: place, category: category)
                    }
                }
            }
        }
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CategoryPlaceRow: View {
    let place: Place
    let category: PlaceCategory

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.callout)
                    .foregroundColor(category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
            }
            Spacer()
            if place.isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PinlyTheme.success)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - İstatistik Pill

private struct DiscoverStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
