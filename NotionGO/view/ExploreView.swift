import SwiftUI
import CoreLocation

struct ExploreView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var showMap = false
    @State private var showRouteFlow = false

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    // MARK: - Computed

    private var nearbyPlaces: [Place] {
        guard let userLoc = locationManager.userLocation else {
            return Array(placeStore.places.prefix(8))
        }
        return placeStore.places
            .filter { $0.coordinate != nil }
            .sorted {
                let a = CLLocation(latitude: $0.coordinate!.latitude, longitude: $0.coordinate!.longitude)
                let b = CLLocation(latitude: $1.coordinate!.latitude, longitude: $1.coordinate!.longitude)
                return userLoc.distance(from: a) < userLoc.distance(from: b)
            }
            .prefix(8)
            .map { $0 }
    }

    private var unvisitedPlaces: [Place] {
        placeStore.places.filter { !$0.isVisited }.prefix(6).map { $0 }
    }

    private var topRatedPlaces: [Place] {
        placeStore.places
            .filter { $0.userRating != nil }
            .sorted { ($0.userRating ?? 0) > ($1.userRating ?? 0) }
            .prefix(6)
            .map { $0 }
    }

    private var categories: [String] { placeStore.allCategories }

    // Suggested route combos: pairs of categories that have places
    private var suggestedCombos: [[String]] {
        let cats = categories
        guard cats.count >= 2 else { return [] }
        var combos: [[String]] = []
        let pairs = [
            ["Kafe", "Park"], ["Restoran", "Müze"], ["Kafe", "Kütüphane"],
            ["Park", "Restoran"], ["Müze", "Kafe"], ["Tarihi", "Restoran"]
        ]
        for pair in pairs {
            let matched = pair.filter { p in cats.contains { $0.lowercased() == p.lowercased() } }
            if matched.count == pair.count { combos.append(matched) }
        }
        // fallback: first 2 categories
        if combos.isEmpty && cats.count >= 2 {
            combos.append(Array(cats.prefix(2)))
        }
        return Array(combos.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if !nearbyPlaces.isEmpty {
                            nearbySection
                        }
                        if !suggestedCombos.isEmpty {
                            suggestedRoutesSection
                        }
                        if !unvisitedPlaces.isEmpty {
                            unvisitedSection
                        }
                        if !topRatedPlaces.isEmpty {
                            topRatedSection
                        }
                        if !categories.isEmpty {
                            categoriesSection
                        }
                        if placeStore.places.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 48)
                }
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            MapView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
        .fullScreenCover(isPresented: $showRouteFlow) {
            CategoryPickerView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
                .environment(\.dismissRouteFlow, {
                    showRouteFlow = false
                    locationManager.stopNavigationTracking()
                    routeManager.reset()
                })
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.subtitle)
                    .padding(10)
                    .background(Circle().fill(t.card))
                    .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text("KEŞFET")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(t.title)
                if !locationManager.currentDistrict.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.system(size: 9))
                        Text(locationManager.currentDistrict).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(t.primary)
                }
            }

            Spacer()

            // Map button
            Button { showMap = true } label: {
                Image(systemName: "map")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(t.buttonText)
                    .padding(10)
                    .background(Circle().fill(t.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Nearby Section

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "YAKINDA", subtitle: "Konumuna en yakın mekanlar")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nearbyPlaces) { place in
                        NearbyPlaceCard(place: place, userLocation: locationManager.userLocation, t: t)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Suggested Routes Section

    private var suggestedRoutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "ÖNERİLEN ROTALAR", subtitle: "Kategori kombinasyonları")

            VStack(spacing: 10) {
                ForEach(suggestedCombos.indices, id: \.self) { i in
                    let combo = suggestedCombos[i]
                    SuggestedRouteRow(categories: combo, t: t) {
                        routeManager.reset()
                        routeManager.selectedCategories = combo
                        showRouteFlow = true
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Unvisited Section

    private var unvisitedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "GİTMEDİKLERİN", subtitle: "Henüz ziyaret etmediğin mekanlar")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(unvisitedPlaces) { place in
                        CompactPlaceCard(place: place, t: t)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Top Rated Section

    private var topRatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "EN İYİLER", subtitle: "En yüksek puanladıkların")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(topRatedPlaces) { place in
                        CompactPlaceCard(place: place, t: t, showRating: true)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "KATEGORİLER", subtitle: "Türe göre keşfet")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(categories, id: \.self) { cat in
                    let count = placeStore.places.filter { $0.category == cat }.count
                    CategoryTile(category: cat, count: count, t: t)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 44))
                .foregroundColor(t.primary.opacity(0.3))
            Text("Henüz mekan yok")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(t.title)
            Text("ADD sekmesinden mekan ekleyerek keşfetmeye başla.")
                .font(.system(size: 13))
                .foregroundColor(t.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helper

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(t.subtitle.opacity(0.5))
            Text(subtitle)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(t.title)
                .tracking(-0.3)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Nearby Place Card

private struct NearbyPlaceCard: View {
    let place: Place
    let userLocation: CLLocation?
    let t: ThemeColors

    private var distanceText: String? {
        guard let coord = place.coordinate, let userLoc = userLocation else { return nil }
        let dist = userLoc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        if dist < 1000 { return "\(Int(dist)) m" }
        return String(format: "%.1f km", dist / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(place.categoryColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: place.categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(place.categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.title)
                    .lineLimit(1)
                Text(place.category)
                    .font(.system(size: 11))
                    .foregroundColor(t.subtitle)
            }

            if let dist = distanceText {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill").font(.system(size: 9))
                    Text(dist).font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(t.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(t.accent.opacity(0.12)))
            }
        }
        .padding(14)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}

// MARK: - Compact Place Card

private struct CompactPlaceCard: View {
    let place: Place
    let t: ThemeColors
    var showRating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(place.categoryColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: place.categoryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(place.categoryColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.title)
                        .lineLimit(1)
                    Text(place.district)
                        .font(.system(size: 10))
                        .foregroundColor(t.subtitle)
                        .lineLimit(1)
                }
            }

            if showRating, let rating = place.userRating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundColor(star <= rating ? t.accent : t.subtitle.opacity(0.25))
                    }
                }
            }

            if !showRating && place.visitCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundColor(t.primary)
                    Text("\(place.visitCount)x").font(.system(size: 10, weight: .medium)).foregroundColor(t.primary)
                }
            }
        }
        .padding(12)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}

// MARK: - Suggested Route Row

private struct SuggestedRouteRow: View {
    let categories: [String]
    let t: ThemeColors
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(categories.indices, id: \.self) { i in
                        ZStack {
                            Circle()
                                .fill(PlaceStyle.color(for: categories[i]).opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(t.bg, lineWidth: 2))
                            Image(systemName: PlaceStyle.icon(for: categories[i]))
                                .font(.system(size: 13))
                                .foregroundColor(PlaceStyle.color(for: categories[i]))
                        }
                        .zIndex(Double(categories.count - i))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(categories.joined(separator: " → "))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.title)
                    Text("\(categories.count) durak · Rota oluştur")
                        .font(.system(size: 11))
                        .foregroundColor(t.subtitle)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(t.primary)
                    .padding(8)
                    .background(Circle().fill(t.accent.opacity(0.15)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(t.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Tile

private struct CategoryTile: View {
    let category: String
    let count: Int
    let t: ThemeColors

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(PlaceStyle.color(for: category).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: PlaceStyle.icon(for: category))
                    .font(.system(size: 18))
                    .foregroundColor(PlaceStyle.color(for: category))
            }
            Text(category)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(t.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundColor(t.subtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}
