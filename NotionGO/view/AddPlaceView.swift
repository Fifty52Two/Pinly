import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore

    @State private var name = ""
    @State private var category = "Genel"
    @State private var address = ""
    @State private var notes = ""
    @State private var isLoadingLocation = false
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil
    @State private var isSaving = false

    let categories = ["Restaurant", "Café", "Park", "Museum", "Historical Site", "Library", "Tatli", "Genel"]

    private let locationManager = CLLocationManager()

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
                                if isLoadingLocation {
                                    ProgressView()
                                        .scaleEffect(0.8)
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
        isLoadingLocation = true
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // Tek seferlik konum al
        Task {
            for _ in 0..<20 {
                if let loc = await getCurrentLocation() {
                    await MainActor.run {
                        currentCoord = loc
                        usedCurrentLocation = true
                        isLoadingLocation = false
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await MainActor.run {
                isLoadingLocation = false
            }
        }
    }

    private func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // LocationManager'dan mevcut konumu al
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // PlaceStore'daki locationManager'dan al — onu environment'tan alamıyoruz,
                // bu yüzden CLLocationManager ile direkt alıyoruz
                let mgr = CLLocationManager()
                if let loc = mgr.location {
                    continuation.resume(returning: loc.coordinate)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Kaydet

    private func save() {
        isSaving = true
        Task {
            if usedCurrentLocation, let coord = currentCoord {
                // Koordinatı direkt kullan, geocoding yapmaya gerek yok
                let place = Place(name: name, category: category, address: "Mevcut Konum", notes: notes)
                place.latitude = coord.latitude
                place.longitude = coord.longitude
                place.locationName = "Mevcut Konum"
                modelContext.insert(place)
                try? modelContext.save()
                placeStore.load(context: modelContext)
            } else {
                // Adres ile geocoding
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
