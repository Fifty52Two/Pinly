import SwiftUI

struct PlacePickerStepView: View {
    let stepIndex: Int

    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    @AppStorage("appTheme") private var storedTheme = "light"
    @AppStorage("searchRadiusKm") private var searchRadiusKm: Double = 5.0
    @State private var goToNext = false
    @State private var showRadiusSettings = false
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var currentCategory: String {
        guard stepIndex < routeManager.selectedCategories.count else { return "" }
        return routeManager.selectedCategories[stepIndex]
    }

    var availablePlaces: [Place] {
        placeStore.places(category: currentCategory, userLocation: locationManager.userLocation, radiusKm: searchRadiusKm)
    }

    var isLastStep: Bool { stepIndex == routeManager.selectedCategories.count - 1 }
    var radiusLabel: String { searchRadiusKm == 0 ? "Tümü" : "\(Int(searchRadiusKm)) km" }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text(currentCategory.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(t.title)
                    Spacer()
                    HStack(spacing: 8) {
                        Button { showRadiusSettings = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 11))
                                Text(radiusLabel)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(t.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(t.accent.opacity(0.15)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            routeManager.reset()
                            dismissRouteFlow()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(t.subtitle)
                                .padding(9)
                                .background(Circle().fill(t.card))
                                .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Progress bar
                StepProgressBar(current: stepIndex + 1, total: routeManager.selectedCategories.count, t: t)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Adım \(stepIndex + 1) / \(routeManager.selectedCategories.count)")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(t.subtitle.opacity(0.5))
                    Text("Bir \(currentCategory) seç")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(t.title)
                        .tracking(-0.3)
                    if !locationManager.currentDistrict.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.fill")
                                .font(.system(size: 10))
                            Text(locationManager.currentDistrict)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(t.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                if availablePlaces.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40))
                            .foregroundColor(t.primary.opacity(0.4))
                        Text("Bu kategoride mekan bulunamadı")
                            .font(.system(size: 15))
                            .foregroundColor(t.subtitle)
                            .multilineTextAlignment(.center)
                        if searchRadiusKm > 0 {
                            Button { showRadiusSettings = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.magnifyingglass")
                                    Text("Arama yarıçapını genişlet (\(radiusLabel))")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(t.primary)
                            }
                        }
                        Button("Bu adımı atla") { goToNext = true }
                            .font(.system(size: 14))
                            .foregroundColor(t.subtitle)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(availablePlaces) { place in
                                StepPlaceRow(
                                    place: place,
                                    isSelected: routeManager.selectedPlaces[currentCategory]?.id == place.id,
                                    t: t
                                ) {
                                    routeManager.selectedPlaces[currentCategory] = place
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        goToNext = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showRadiusSettings) {
            RadiusSettingsSheet(searchRadiusKm: $searchRadiusKm, t: t)
        }
        .navigationDestination(isPresented: $goToNext) {
            if isLastStep {
                RouteSummaryView()
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
                    .environmentObject(routeManager)
            } else {
                PlacePickerStepView(stepIndex: stepIndex + 1)
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
                    .environmentObject(routeManager)
            }
        }
    }
}

// MARK: - Step Progress Bar

struct StepProgressBar: View {
    let current: Int
    let total: Int
    let t: ThemeColors

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(t.card)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 3)
                    .fill(t.accent)
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 4)
                    .animation(.spring(), value: current)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step Place Row

struct StepPlaceRow: View {
    let place: Place
    let isSelected: Bool
    let t: ThemeColors
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? t.accent : t.card)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(t.buttonText)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(t.title)
                    Text(place.district)
                        .font(.system(size: 11))
                        .foregroundColor(t.subtitle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(t.subtitle.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? t.accent.opacity(0.1) : t.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? t.accent.opacity(0.4) : t.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Radius Settings Sheet

struct RadiusSettingsSheet: View {
    @Binding var searchRadiusKm: Double
    let t: ThemeColors
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("1 km", 1), ("3 km", 3), ("5 km", 5),
        ("10 km", 10), ("25 km", 25), ("Tümü", 0),
    ]

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("ARAMA YARIAÇAPI")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(t.title)
                    .padding(.top, 24)
                    .padding(.bottom, 6)

                Text("Anlık konumuna göre kaç km içindeki mekanlar gösterilsin?")
                    .font(.system(size: 13))
                    .foregroundColor(t.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(options, id: \.value) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                searchRadiusKm = option.value
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(t.title)
                                    Text(option.value == 0 ? "Tüm kayıtlı mekanlar" : "Konumundan \(option.label) içindeki mekanlar")
                                        .font(.system(size: 11))
                                        .foregroundColor(t.subtitle)
                                }
                                Spacer()
                                if searchRadiusKm == option.value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(t.primary)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(searchRadiusKm == option.value ? t.accent.opacity(0.1) : t.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(searchRadiusKm == option.value ? t.cardBorder : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}
