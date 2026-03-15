import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct EditPlaceView: View {
    let place: Place

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore

    @State private var name: String
    @State private var category: String
    @State private var address: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var isLoadingLocation = false
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil

    let categories = ["Restaurant", "Café", "Park", "Museum", "Historical Site", "Library", "Tatli", "Genel"]

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
                Section(header: Text("Mekan Bilgileri")) {
                    TextField("Mekan Adı", text: $name)
                    Picker("Kategori", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
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
                                if isLoadingLocation {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text(isLoadingLocation ? "Konum alınıyor..." : "Mevcut Konumumu Kullan")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }
                        .disabled(isLoadingLocation)
                    }
                }

                Section(header: Text("Notlar")) {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Mekanı Düzenle")
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
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
    }

    private func fetchCurrentLocation() {
        isLoadingLocation = true
        Task {
            for _ in 0..<20 {
                if let coord = await getCurrentCoord() {
                    await MainActor.run {
                        currentCoord = coord
                        usedCurrentLocation = true
                        isLoadingLocation = false
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await MainActor.run { isLoadingLocation = false }
        }
    }

    private func getCurrentCoord() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let mgr = CLLocationManager()
                continuation.resume(returning: mgr.location?.coordinate)
            }
        }
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
            } else if addressChanged {
                place.address = address
                if let coord = await geocode(name: name, address: address) {
                    place.latitude = coord.latitude
                    place.longitude = coord.longitude
                }
            }

            await MainActor.run {
                try? modelContext.save()
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
