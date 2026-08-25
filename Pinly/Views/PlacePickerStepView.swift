import SwiftUI

struct PlacePickerStepView: View {
    let stepIndex: Int

    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager

    @StateObject private var viewModel = PlacePickerStepViewModel()

    @AppStorage("searchRadiusKm") private var searchRadiusKm: Double = 5.0
    @State private var goToNext = false
    @State private var showRadiusSettings = false
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    var currentCategory: String {
        viewModel.currentCategory(stepIndex: stepIndex, tracker: routeManager)
    }

    var availablePlaces: [Place] {
        viewModel.availablePlaces(
            category: currentCategory,
            placeStore: placeStore,
            userLocation: locationManager.userLocation,
            radiusKm: searchRadiusKm
        )
    }

    var isLastStep: Bool {
        viewModel.isLastStep(stepIndex: stepIndex, tracker: routeManager)
    }

    var radiusLabel: String {
        viewModel.radiusLabel(searchRadiusKm)
    }

    var selectionCount: Int {
        viewModel.selectionCount(category: currentCategory, tracker: routeManager)
    }

    /// routePlaces'i RouteSummaryView oluşmadan ÖNCE, kesin sırayla mühürleyip
    /// geçişi tetikler — onAppear sıralamasına güvenmek riskli (RouteSummaryView'in
    /// kendi onAppear'ı routePlaces'i henüz boşken okuyup rota hesaplamasını
    /// başlatabilirdi).
    private func advanceToNext() {
        if isLastStep {
            routeManager.commitCategorySelection()
        }
        goToNext = true
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
                Text(String(format: NSLocalizedString("%@ seç", comment: ""), PlaceCategory.from(currentCategory).localizedName))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(NSLocalizedString("Birden fazla mekan seçebilirsin", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        advanceToNext()
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
                                isSelected: viewModel.isSelected(place, category: currentCategory, tracker: routeManager)
                            ) {
                                withAnimation(.spring(response: 0.25)) {
                                    viewModel.togglePlace(place, category: currentCategory, tracker: routeManager)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !availablePlaces.isEmpty {
                Button {
                    advanceToNext()
                } label: {
                    HStack {
                        Text(selectionCount > 0
                             ? String(format: NSLocalizedString("Devam Et (%lld mekan)", comment: ""), selectionCount)
                             : NSLocalizedString("Devam Et", comment: ""))
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(PinlyTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectionCount > 0 ? PinlyTheme.primary : PinlyTheme.primary.opacity(0.35))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .disabled(selectionCount == 0)
                .background(.regularMaterial)
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
                .accessibilityLabel(NSLocalizedString("Kapat", comment: ""))
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
                                          : PinlyTheme.fillMuted)
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
                    .fill(PinlyTheme.fillMuted)
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
        // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (33 · Sırayla mekan
        // seç) satır — solda dolu renkli kategori ikonu + sağda seçiliyken beliren
        // check dairesi, 2px vurgu konturu (birebir).
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(place.categoryColor)
                        .frame(width: 34, height: 34)
                    Image(systemName: place.categoryIcon)
                        .font(.subheadline)
                        .foregroundColor(.white)
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

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(PinlyTheme.primary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? PinlyTheme.primary : PinlyTheme.hairline, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
