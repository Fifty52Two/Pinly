import SwiftUI
import SwiftData
import CoreLocation

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.entitlements) private var entitlements
    @Environment(\.badges) private var badgeService

    @State private var name = ""
    @State private var category = PlaceCategory.general
    @State private var address = ""
    @State private var isLocating = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Konum", comment: "")) {
                    if isLocating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(NSLocalizedString("Konum alınıyor...", comment: ""))
                                .foregroundStyle(.secondary)
                        }
                    } else if locationManager.userLocation != nil {
                        Label(
                            address.isEmpty
                                ? NSLocalizedString("Konum hazır", comment: "")
                                : address,
                            systemImage: "location.fill"
                        )
                        .foregroundStyle(.green)
                    } else {
                        Label(NSLocalizedString("Konum alınamadı", comment: ""), systemImage: "location.slash")
                            .foregroundStyle(.red)
                    }
                }

                Section(NSLocalizedString("Mekan Bilgisi", comment: "")) {
                    TextField(NSLocalizedString("Mekan adı", comment: ""), text: $name)
                    Picker(NSLocalizedString("Kategori", comment: ""), selection: $category) {
                        ForEach(PlaceCategory.allCases, id: \.self) { cat in
                            Label(cat.localizedName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Hızlı Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
        }
        .onAppear { fetchLocation() }
        .sheet(isPresented: $showPaywall) { PaywallView(onDismiss: { showPaywall = false }) }
    }

    // MARK: - Konum Al

    private func fetchLocation() {
        locationManager.requestLocation()
        // Kısa bekleme sonrası konum geldi mi kontrol et
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLocating = false
            if let loc = locationManager.userLocation {
                reverseGeocode(loc)
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.name, p.subLocality, p.locality].compactMap { $0 }
            address = parts.joined(separator: ", ")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(NSLocalizedString("Ekle", comment: "")) { save() }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLocating)
        }
    }

    // MARK: - Kaydet

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else {
            showPaywall = true
            return
        }

        let place = Place(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            address: address
        )

        if let loc = locationManager.userLocation {
            place.latitude = loc.coordinate.latitude
            place.longitude = loc.coordinate.longitude
            place.locationName = address
        }

        modelContext.insert(place)
        placeStore.save(context: modelContext)
        placeStore.load(context: modelContext)

        let newBadges = badgeService.check(placeStore: placeStore)
        placeStore.pendingBadges.append(contentsOf: newBadges)

        dismiss()
    }
}
