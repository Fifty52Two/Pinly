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

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Mekan Bilgileri")) {
                    TextField("Mekan Adı", text: $name)
                    Picker("Kategori", selection: $category) {
                        ForEach(PlaceCategory.allCases, id: \.rawValue) { cat in
                            Text(cat.rawValue).tag(cat.rawValue)
                        }
                    }
                }

                Section(header: Text("Konum")) {
                    if usedCurrentLocation {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Mevcut konum kullanılıyor")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Button("Değiştir") {
                                usedCurrentLocation = false
                                currentCoord = nil
                                address = ""
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    } else {
                        TextField("Adres (Örn: Kadıköy, İstanbul)", text: $address)

                        Button {
                            fetchCurrentLocation()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Mevcut Konumumu Kullan")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }

                Section(header: Text("Notlar")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Yeni Mekan Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Kaydet")
                        }
                    }
                    .disabled(name.isEmpty || (!usedCurrentLocation && address.isEmpty) || isSaving)
                }
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
                await placeStore.addPlace(
                    name: name,
                    category: category,
                    address: address,
                    notes: notes,
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
