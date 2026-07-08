import SwiftUI
import SwiftData
import CoreLocation
import MapKit

// Kart tabanlı özel form — AddPlaceView ile aynı bileşenler
// (PlaceFormComponents). Kayıt/geocode mantığı değişmedi.

struct EditPlaceView: View {
    let place: Place

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager

    @State private var name: String
    @State private var category: String
    @State private var address: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil

    // Haritada Pinle
    @State private var showMapPicker = false
    @State private var pinnedCoord: CLLocationCoordinate2D? = nil
    @State private var pinnedAddress = ""

    init(place: Place) {
        self.place = place
        _name = State(initialValue: place.name)
        _category = State(initialValue: place.category)
        _address = State(initialValue: place.address)
        _notes = State(initialValue: place.notes)
    }

    private var canSave: Bool { !name.isEmpty && !isSaving }

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
                                    address = place.address
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
            .navigationTitle(NSLocalizedString("Mekanı Düzenle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                        .tint(PinlyTheme.primary)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                // Düzenleme modu: mevcut koordinatla başla
                MapPinPickerView(initialCoordinate: pinnedCoord ?? place.coordinate) { coord, resolvedAddress in
                    pinnedCoord = coord
                    pinnedAddress = resolvedAddress
                    address = resolvedAddress
                }
                .environmentObject(locationManager)
            }
        }
    }

    private func fetchCurrentLocation() {
        guard let loc = locationManager.userLocation else {
            locationManager.requestLocation()
            return
        }
        currentCoord = loc.coordinate
        usedCurrentLocation = true
    }

    private func save() {
        isSaving = true
        let addressChanged = address != place.address && !address.isEmpty
        Task {
            place.name = name
            place.category = category
            place.notes = notes

            if usedCurrentLocation, let coord = currentCoord {
                place.latitude = coord.latitude
                place.longitude = coord.longitude
                place.address = "Mevcut Konum"
                place.locationName = "Mevcut Konum"
            } else if let coord = pinnedCoord {
                // Haritadan pinlenen koordinat — geocode atlanır
                place.latitude = coord.latitude
                place.longitude = coord.longitude
                place.address = address
                place.locationName = address
            } else if addressChanged {
                place.address = address
                if let coord = await geocode(name: name, address: address) {
                    place.latitude = coord.latitude
                    place.longitude = coord.longitude
                }
            }

            await MainActor.run {
                placeStore.save(context: modelContext)
                placeStore.load(context: modelContext)
                isSaving = false
                dismiss()
            }
        }
    }

    private func geocode(name: String, address: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(name) \(address)"
            MKLocalSearch(request: request).start { response, _ in
                if let coord = response?.mapItems.first?.placemark.coordinate {
                    continuation.resume(returning: coord)
                    return
                }
                let req2 = MKLocalSearch.Request()
                req2.naturalLanguageQuery = address
                MKLocalSearch(request: req2).start { resp2, _ in
                    continuation.resume(returning: resp2?.mapItems.first?.placemark.coordinate)
                }
            }
        }
    }
}
