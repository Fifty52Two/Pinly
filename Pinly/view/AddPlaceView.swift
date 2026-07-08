import SwiftUI
import SwiftData
import CoreLocation
import MapKit

// Kart tabanlı özel form — sistem Form yerine slate tema bileşenleri
// (PlaceFormComponents). Kayıt mantığı değişmedi.

struct AddPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager

    @State private var name = ""
    @State private var category = PlaceCategory.general.rawValue
    @State private var address = ""
    @State private var notes = ""
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil
    @State private var isSaving = false

    // Haritada Pinle
    @State private var showMapPicker = false
    @State private var pinnedCoord: CLLocationCoordinate2D? = nil
    @State private var pinnedAddress = ""

    private var canSave: Bool {
        !name.isEmpty && (usedCurrentLocation || !address.isEmpty) && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Mekan bilgileri
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("Mekan Bilgileri", comment: ""))
                        PinlyField(
                            icon: "mappin.circle",
                            placeholder: NSLocalizedString("Mekan Adı", comment: ""),
                            text: $name
                        )
                        PinlyCategoryGrid(selection: $category)
                    }

                    // Konum
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("Konum", comment: ""))

                        if usedCurrentLocation {
                            PinlyStatusRow(
                                icon: "location.fill",
                                tint: PinlyTheme.primary,
                                text: NSLocalizedString("Mevcut konum kullanılıyor", comment: ""),
                                actionTitle: NSLocalizedString("Değiştir", comment: "")
                            ) {
                                usedCurrentLocation = false
                                currentCoord = nil
                                address = ""
                            }
                        } else {
                            PinlyField(
                                icon: "magnifyingglass",
                                placeholder: NSLocalizedString("Adres (Örn: Kadıköy, İstanbul)", comment: ""),
                                text: $address
                            )
                            .onChange(of: address) {
                                // Adres elle değiştirilirse pinlenen konum geçersiz olur
                                if pinnedCoord != nil && address != pinnedAddress {
                                    pinnedCoord = nil
                                    pinnedAddress = ""
                                }
                            }

                            if pinnedCoord != nil {
                                PinlyStatusRow(
                                    icon: "checkmark.circle.fill",
                                    tint: .green,
                                    text: NSLocalizedString("Konum haritadan seçildi", comment: ""),
                                    actionTitle: NSLocalizedString("Kaldır", comment: "")
                                ) {
                                    pinnedCoord = nil
                                    pinnedAddress = ""
                                    address = ""
                                }
                            }

                            HStack(spacing: 12) {
                                PinlyLocationOption(
                                    icon: "location.fill",
                                    title: NSLocalizedString("Mevcut Konumumu Kullan", comment: "")
                                ) {
                                    fetchCurrentLocation()
                                }
                                PinlyLocationOption(
                                    icon: "mappin.and.ellipse",
                                    title: NSLocalizedString("Haritada Pinle", comment: ""),
                                    isActive: pinnedCoord != nil
                                ) {
                                    showMapPicker = true
                                }
                            }
                        }
                    }

                    // Notlar
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("Notlar", comment: ""))
                        PinlyNotesEditor(
                            placeholder: NSLocalizedString("Bu mekan için not ekle...", comment: ""),
                            text: $notes
                        )
                    }

                    // Kaydet
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(NSLocalizedString("Kaydet", comment: ""))
                        }
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(20)
            }
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Yeni Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                        .tint(PinlyTheme.primary)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPinPickerView(initialCoordinate: pinnedCoord) { coord, resolvedAddress in
                    pinnedCoord = coord
                    pinnedAddress = resolvedAddress
                    address = resolvedAddress
                }
                .environmentObject(locationManager)
            }
        }
    }

    // MARK: - Mevcut Konumu Al

    private func fetchCurrentLocation() {
        guard let loc = locationManager.userLocation else {
            // Konum henüz alınmadıysa tekrar iste
            locationManager.requestLocation()
            return
        }
        currentCoord = loc.coordinate
        usedCurrentLocation = true
    }

    // MARK: - Kaydet

    private func save() {
        isSaving = true
        Task {
            if usedCurrentLocation, let coord = currentCoord {
                let place = Place(name: name, category: category, address: "Mevcut Konum", notes: notes)
                place.latitude = coord.latitude
                place.longitude = coord.longitude
                place.locationName = "Mevcut Konum"
                modelContext.insert(place)
                placeStore.save(context: modelContext)
                placeStore.load(context: modelContext)
            } else {
                // Haritadan pinlendiyse koordinat direkt kullanılır, geocode atlanır
                await placeStore.addPlace(
                    name: name,
                    category: category,
                    address: address,
                    notes: notes,
                    coordinate: pinnedCoord,
                    context: modelContext
                )
            }
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
