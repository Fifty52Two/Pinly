import SwiftUI
import MapKit
// MARK: - Route Share Picker

struct RouteSharePickerView: View {
    let routePlaces: [Place]
    @Binding var name: String
    @Binding var category: RouteCategory
    var onShare: () -> Void = {}

    @Environment(\.routeURLCoding) private var routeURLCoding

    private var shareURL: URL? {
        routeURLCoding.buildRouteURL(
            for: routePlaces,
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name,
            category: category
        )
    }

    /// Tüm koordinatlı durakları kapsayan harita bölgesi (koordinat yoksa nil → harita gizlenir)
    private var previewRegion: MKCoordinateRegion? {
        let coords = routePlaces.compactMap { $0.coordinate }
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("Rotayı Paylaş", comment: ""))
                .font(.headline)
                .padding(.top, 24)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Rota Adı (isteğe bağlı)", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                TextField("örn. Kadıköy Kahvaltı Turu", text: $name)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PinlyTheme.fillMuted)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Kategori", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                HStack(spacing: 10) {
                    ForEach(RouteCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(category == cat ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category == cat ? PinlyTheme.primary : PinlyTheme.fillMuted)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Paylaşım önizlemesi: mini harita + durak listesi (FAZ 5.3)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let region = previewRegion {
                        Map(initialPosition: .region(region)) {
                            ForEach(Array(routePlaces.enumerated()), id: \.offset) { index, place in
                                if let coord = place.coordinate {
                                    Annotation("", coordinate: coord) {
                                        ZStack {
                                            Circle()
                                                .fill(PinlyTheme.primary)
                                                .frame(width: 22, height: 22)
                                            Text("\(index + 1)")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(emphasis: .muted))
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(routePlaces.prefix(4).enumerated()), id: \.offset) { index, place in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(PinlyTheme.primary))
                                Text(place.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        if routePlaces.count > 4 {
                            Text(String(format: NSLocalizedString("+ %lld durak daha", comment: ""), routePlaces.count - 4))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 30)
                        }
                    }
                    .padding(12)
                    .background(PinlyTheme.fillMuted)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            if let url = shareURL {
                ShareLink(
                    item: url,
                    subject: Text(NSLocalizedString("Pinly Rotası", comment: "")),
                    message: Text(routePlaces.map(\.name).joined(separator: " → "))
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(NSLocalizedString("Paylaş", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PinlyTheme.primary)
                    .cornerRadius(14)
                }
                .simultaneousGesture(TapGesture().onEnded { onShare() })
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}
