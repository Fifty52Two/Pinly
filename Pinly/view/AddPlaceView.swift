import SwiftUI
import SwiftData
import CoreLocation
import MapKit

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

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("Mekan Bilgileri", comment: ""))) {
                    TextField(NSLocalizedString("Mekan Adı", comment: ""), text: $name)
                    Picker(NSLocalizedString("Kategori", comment: ""), selection: $category) {
                        ForEach(PlaceCategory.allCases, id: \.rawValue) { cat in
                            Text(cat.rawValue).tag(cat.rawValue)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Konum", comment: ""))) {
                    if usedCurrentLocation {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("Mevcut konum kullanılıyor", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Button(NSLocalizedString("Değiştir", comment: "")) {
                                usedCurrentLocation = false
                                currentCoord = nil
                                address = ""
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    } else {
                        TextField(NSLocalizedString("Adres (Örn: Kadıköy, İstanbul)", comment: ""), text: $address)
                            .onChange(of: address) {
                                // Adres elle değiştirilirse pinlenen konum geçersiz olur
                                if pinnedCoord != nil && address != pinnedAddress {
                                    pinnedCoord = nil
                                    pinnedAddress = ""
                                }
                            }

                        if pinnedCoord != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("Konum haritadan seçildi", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                                Button(NSLocalizedString("Kaldır", comment: "")) {
                                    pinnedCoord = nil
                                    pinnedAddress = ""
                                    address = ""
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }

                        Button {
                            fetchCurrentLocation()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(NSLocalizedString("Mevcut Konumumu Kullan", comment: ""))
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }

                        Button {
                            showMapPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(NSLocalizedString("Haritada Pinle", comment: ""))
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(PinlyTheme.primary)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Notlar", comment: ""))) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(NSLocalizedString("Yeni Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(NSLocalizedString("Kaydet", comment: ""))
                        }
                    }
                    .disabled(name.isEmpty || (!usedCurrentLocation && address.isEmpty) || isSaving)
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
