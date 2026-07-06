import SwiftUI
import SwiftData
import CoreLocation
import MapKit

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
                                    address = place.address
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
                        .frame(height: 120)
                }
            }
            .navigationTitle(NSLocalizedString("Mekanı Düzenle", comment: ""))
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
                    .disabled(name.isEmpty || isSaving)
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
