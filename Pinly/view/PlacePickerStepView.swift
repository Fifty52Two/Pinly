import SwiftUI

struct PlacePickerStepView: View {
    let stepIndex: Int

    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    @AppStorage("searchRadiusKm") private var searchRadiusKm: Double = 5.0
    @State private var goToNext = false
    @State private var showRadiusSettings = false
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    var currentCategory: String {
        guard stepIndex < routeManager.selectedCategories.count else { return "" }
        return routeManager.selectedCategories[stepIndex]
    }

    var availablePlaces: [Place] {
        placeStore.places(
            category: currentCategory,
            userLocation: locationManager.userLocation,
            radiusKm: searchRadiusKm
        )
    }

    var isLastStep: Bool {
        stepIndex == routeManager.selectedCategories.count - 1
    }

    var radiusLabel: String {
        searchRadiusKm == 0 ? "Tümü" : "\(Int(searchRadiusKm)) km"
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(current: stepIndex + 1, total: routeManager.selectedCategories.count)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

            VStack(spacing: 6) {
                Text(String(format: NSLocalizedString("Adım %lld / %lld", comment: ""), stepIndex + 1, routeManager.selectedCategories.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: NSLocalizedString("Bir %@ seç", comment: ""), PlaceCategory.from(currentCategory).localizedName))
                    .font(.title2)
                    .fontWeight(.bold)
                if !locationManager.currentDistrict.isEmpty {
                    Label(locationManager.currentDistrict, systemImage: "mappin.fill")
                        .font(.subheadline)
                        .foregroundColor(PinlyTheme.primary)
                }
            }
            .padding(.bottom, 20)

            if availablePlaces.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("Bu kategoride mekan bulunamadı", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if searchRadiusKm > 0 {
                        Button {
                            showRadiusSettings = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "location.magnifyingglass")
                                Text(String(format: NSLocalizedString("Arama yarıçapını genişlet (%@)", comment: ""), radiusLabel))
                                    .font(.subheadline)
                            }
                            .foregroundColor(PinlyTheme.primary)
                        }
                    }
                    Button(NSLocalizedString("Bu adımı atla", comment: "")) {
                        goToNext = true
                    }
                    .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availablePlaces) { place in
                            PlaceRow(
                                place: place,
                                isSelected: routeManager.selectedPlaces[currentCategory]?.id == place.id
                            ) {
                                routeManager.selectedPlaces[currentCategory] = place
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
        .navigationTitle(currentCategory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    routeManager.reset()
                    dismissRouteFlow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showRadiusSettings = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle")
                        Text(radiusLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(PinlyTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showRadiusSettings) {
            RadiusSettingsSheet(searchRadiusKm: $searchRadiusKm)
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

// MARK: - Radius Settings Sheet

struct RadiusSettingsSheet: View {
    @Binding var searchRadiusKm: Double
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("1 km", 1),
        ("3 km", 3),
        ("5 km", 5),
        ("10 km", 10),
        ("25 km", 25),
        ("Tümü", 0),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(NSLocalizedString("Anlık konumuna göre hangi mesafedeki mekanlar gösterilsin?", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(options, id: \.value) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                searchRadiusKm = option.value
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    if option.value == 0 {
                                        Text(NSLocalizedString("Tüm kayıtlı mekanları göster", comment: ""))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(String(format: NSLocalizedString("Konumundan %@ içindeki mekanlar", comment: ""), option.label))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if searchRadiusKm == option.value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(PinlyTheme.primary)
                                        .font(.title3)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(searchRadiusKm == option.value
                                          ? PinlyTheme.primary.opacity(0.08)
                                          : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(searchRadiusKm == option.value ? PinlyTheme.primary : .clear, lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("Arama Yarıçapı", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(PinlyTheme.primary)
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 6)
                    .animation(.spring(), value: current)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Place Row

struct PlaceRow: View {
    let place: Place
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? PinlyTheme.primary : Color(.systemGray5))
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(place.district)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? PinlyTheme.primary.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? PinlyTheme.primary : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
