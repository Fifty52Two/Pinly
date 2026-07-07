import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore

    @AppStorage("appTheme") private var storedTheme = "light"

    @State private var name = ""
    @State private var category = "Genel"
    @State private var address = ""
    @State private var notes = ""
    @State private var isLoadingLocation = false
    @State private var usedCurrentLocation = false
    @State private var currentCoord: CLLocationCoordinate2D? = nil
    @State private var isSaving = false
    @State private var showCategoryPicker = false

    let categories = ["Restaurant", "Café", "Park", "Museum", "Historical Site", "Library", "Tatli", "Genel"]

    private var t: ThemeColors { ThemeColors.make(storedTheme) }
    private var canSave: Bool { !name.isEmpty && (usedCurrentLocation || !address.isEmpty) && !isSaving }

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

                    Text("YENİ MEKAN")
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
                        // Name
                        fieldSection(label: "MEKAN ADI") {
                            TextField("Örn: Karaköy Lokantası", text: $name)
                                .font(.system(size: 15))
                                .foregroundColor(t.title)
                        }

                        // Category
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

                        // Location
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
                                        address = ""
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(t.destructive)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    TextField("Adres (Örn: Kadıköy, İstanbul)", text: $address)
                                        .font(.system(size: 15))
                                        .foregroundColor(t.title)

                                    Divider()
                                        .background(t.separator)

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

                        // Notes
                        fieldSection(label: "NOTLAR") {
                            TextField("Bu mekan hakkında bir şeyler yaz...", text: $notes, axis: .vertical)
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
                content()
                    .padding(14)
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
            await MainActor.run { isLoadingLocation = false }
        }
    }

    private func getCurrentLocation() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let mgr = CLLocationManager()
                continuation.resume(returning: mgr.location?.coordinate)
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            if usedCurrentLocation, let coord = currentCoord {
                let place = Place(name: name, category: category, address: "Mevcut Konum", notes: notes)
                place.latitude = coord.latitude
                place.longitude = coord.longitude
                place.locationName = "Mevcut Konum"
                modelContext.insert(place)
                try? modelContext.save()
                placeStore.load(context: modelContext)
            } else {
                await placeStore.addPlace(name: name, category: category, address: address, notes: notes, context: modelContext)
            }
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Category Sheet Picker

struct CategorySheetPicker: View {
    @Binding var selected: String
    let categories: [String]
    let t: ThemeColors
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("KATEGORİ")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(t.title)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selected = cat
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(PlaceStyle.color(for: cat).opacity(0.18)).frame(width: 36, height: 36)
                                        Image(systemName: PlaceStyle.icon(for: cat))
                                            .font(.system(size: 14))
                                            .foregroundColor(PlaceStyle.color(for: cat))
                                    }
                                    Text(cat)
                                        .font(.system(size: 15, weight: selected == cat ? .semibold : .regular))
                                        .foregroundColor(t.title)
                                    Spacer()
                                    if selected == cat {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(t.primary)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selected == cat ? t.accent.opacity(0.12) : t.card)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected == cat ? t.cardBorder : Color.clear, lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
