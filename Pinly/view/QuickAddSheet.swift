import SwiftUI
import SwiftData
import CoreLocation

// Kart tabanlı özel form — Add/Edit ile aynı bileşenler
// (PlaceFormComponents). Konum alma / kaydetme mantığı değişmedi.

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.entitlements) private var entitlements
    @Environment(\.badges) private var badgeService

    @State private var name = ""
    @State private var category = PlaceCategory.general.rawValue
    @State private var address = ""
    @State private var isLocating = true
    @State private var showPaywall = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLocating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Konum durumu
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("Konum", comment: ""))
                        if isLocating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(NSLocalizedString("Konum alınıyor...", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PinlyTheme.surface))
                        } else if locationManager.userLocation != nil {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text(address.isEmpty
                                     ? NSLocalizedString("Konum hazır", comment: "")
                                     : address)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.10)))
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "location.slash")
                                    .foregroundColor(PinlyTheme.accent)
                                Text(NSLocalizedString("Konum alınamadı", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(PinlyTheme.accent)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PinlyTheme.accent.opacity(0.10)))
                        }
                    }

                    // Mekan bilgisi
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("Mekan Bilgisi", comment: ""))
                        PinlyField(
                            icon: "mappin.circle",
                            placeholder: NSLocalizedString("Mekan adı", comment: ""),
                            text: $name
                        )
                        PinlyCategoryGrid(selection: $category)
                    }

                    // Ekle
                    Button {
                        save()
                    } label: {
                        Text(NSLocalizedString("Ekle", comment: ""))
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(20)
            }
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Hızlı Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                        .tint(PinlyTheme.primary)
                }
            }
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

    // MARK: - Kaydet

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        guard entitlements.canAddPlace(currentCount: placeStore.places.count) else {
            showPaywall = true
            return
        }

        let place = Place(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
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
