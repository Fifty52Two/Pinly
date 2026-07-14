import SwiftUI
import MapKit

// MARK: - Mekan Detay (Salt Okunur)

struct PlaceDetailView: View {
    let place: Place
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showShare = false

    private var category: PlaceCategory { PlaceCategory.from(place.category) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mapPreview
                infoCard
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditPlaceView(place: place)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showShare) {
            SharePlaceView(place: place)
        }
    }

    // MARK: - Harita Önizleme

    private var mapPreview: some View {
        Group {
            if let lat = place.latitude, let lon = place.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Annotation(place.name, coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 36, height: 36)
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
                .mapStyle(.standard(emphasis: .muted))
                .frame(height: 220)
                .allowsHitTesting(false)
            } else {
                ZStack {
                    Color(.systemGray6)
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Konum yok", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 120)
            }
        }
    }

    // MARK: - Bilgi Kartı

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Kategori + ziyaret durumu
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundColor(category.color)
                    }
                    Text(category.localizedName)
                        .font(.subheadline)
                        .foregroundColor(category.color)
                        .fontWeight(.medium)
                }
                Spacer()
                if place.isVisited {
                    Label(NSLocalizedString("Ziyaret Edildi", comment: ""), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label(NSLocalizedString("Gidilecek", comment: ""), systemImage: "bookmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // İsim
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            // İstatistikler
            HStack(spacing: 0) {
                DetailStatPill(value: "\(place.visitCount)", label: NSLocalizedString("Ziyaret", comment: ""))
                Divider().frame(height: 32)
                DetailStatPill(
                    value: place.userRating.map { "\($0)/5" } ?? "—",
                    label: NSLocalizedString("Puan", comment: "")
                )
                if place.latitude != nil {
                    Divider().frame(height: 32)
                    DetailStatPill(systemImage: "mappin.and.ellipse", label: NSLocalizedString("Konum", comment: ""))
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Puan yıldızları
            if let rating = place.userRating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundColor(star <= rating ? .yellow : Color(.systemGray4))
                    }
                }
            }

            // Adres
            if !place.address.isEmpty {
                DetailRow(icon: "mappin.and.ellipse", color: .red, text: place.address)
            }

            // Notlar
            if !place.notes.isEmpty {
                DetailRow(icon: "note.text", color: .orange, text: place.notes)
            }

            // Düzenle + Paylaş butonları
            HStack(spacing: 12) {
                Button {
                    showEdit = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text(NSLocalizedString("Düzenle", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PinlyTheme.primary.opacity(0.1))
                    .foregroundColor(PinlyTheme.primary)
                    .cornerRadius(14)
                }

                Button {
                    showShare = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(NSLocalizedString("Paylaş", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(14)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Yardımcı görünümler

private struct DetailRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

private struct DetailStatPill: View {
    var value: String? = nil
    var systemImage: String? = nil
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundColor(PinlyTheme.primary)
            } else {
                Text(value ?? "—")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
