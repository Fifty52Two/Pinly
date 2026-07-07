import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct EditPlaceView: View {
    let place: Place

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore

    @AppStorage("appTheme") private var storedTheme = "light"

    @State private var name: String
    @State private var category: String
    @State private var address: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var isLoadingLocation = false
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil
    @State private var showCategoryPicker = false

    let categories = ["Restaurant", "Café", "Park", "Museum", "Historical Site", "Library", "Tatli", "Genel"]

    private var t: ThemeColors { ThemeColors.make(storedTheme) }
    private var canSave: Bool { !name.isEmpty && !isSaving }

    init(place: Place) {
        self.place = place
        _name = State(initialValue: place.name)
        _category = State(initialValue: place.category)
        _address = State(initialValue: place.address)
        _notes = State(initialValue: place.notes)
    }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Text("İptal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(t.subtitle)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("MEKAN DÜZENLE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(t.title)

                    Spacer()

                    Button { save() } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(t.buttonText).scaleEffect(0.8)
                            } else {
                                Text("Kaydet")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(canSave ? t.buttonText : t.subtitle.opacity(0.4))
                            }
                        }
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .background(canSave ? t.accent : t.card)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 20) {
                        fieldSection(label: "MEKAN ADI") {
                            TextField("Mekan adı", text: $name)
                                .font(.system(size: 15))
                                .foregroundColor(t.title)
                        }

                        fieldSection(label: "KATEGORİ") {
                            Button { showCategoryPicker = true } label: {
                                HStack {
                                    Text(category)
                                        .font(.system(size: 15))
                                        .foregroundColor(t.title)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(t.subtitle.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        fieldSection(label: "KONUM") {
                            if usedCurrentLocation {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(t.primary)
                                    Text("Mevcut konum kullanılıyor")
                                        .font(.system(size: 14))
                                        .foregroundColor(t.primary)
                                    Spacer()
                                    Button("Değiştir") {
                                        usedCurrentLocation = false
                                        currentCoord = nil
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(t.destructive)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    TextField("Adres", text: $address)
                                        .font(.system(size: 15))
                                        .foregroundColor(t.title)

                                    Divider().background(t.separator)

                                    Button { fetchCurrentLocation() } label: {
                                        HStack(spacing: 7) {
                                            if isLoadingLocation {
                                                ProgressView().tint(t.primary).scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(t.primary)
                                            }
                                            Text(isLoadingLocation ? "Konum alınıyor..." : "Mevcut Konumumu Kullan")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(t.primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isLoadingLocation)
                                }
                            }
                        }

                        fieldSection(label: "NOTLAR") {
                            TextField("Notlar...", text: $notes, axis: .vertical)
                                .font(.system(size: 15))
                                .foregroundColor(t.title)
                                .lineLimit(4...8)
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showCategoryPicker) {
            CategorySheetPicker(selected: $category, categories: categories, t: t)
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundColor(t.subtitle.opacity(0.55))
            VStack(spacing: 0) {
                content().padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(t.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.cardBorder, lineWidth: 1))
            )
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
