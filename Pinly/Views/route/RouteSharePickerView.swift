import SwiftUI
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

            Spacer()

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
