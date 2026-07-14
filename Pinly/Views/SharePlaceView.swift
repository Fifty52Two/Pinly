import SwiftUI

struct SharePlaceView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.routeURLCoding) private var routeURLCoding
    @Environment(\.qrCodeGenerator) private var qrCodeGenerator

    private var shareURL: URL? { routeURLCoding.buildURL(for: place) }
    private var qrImage: UIImage? {
        guard let url = shareURL else { return nil }
        return qrCodeGenerator.generateQRCode(from: url.absoluteString)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Mekan bilgisi
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(place.categoryColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: place.categoryIcon)
                            .font(.title2)
                            .foregroundColor(place.categoryColor)
                    }
                    Text(place.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(place.placeCategory.localizedName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // QR Kod
                if let qr = qrImage {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                                )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(PinlyTheme.fillMuted)
                        .frame(width: 220, height: 220)
                        .overlay(
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                        )
                }

                Text(NSLocalizedString("QR kodu okutarak veya linki paylaşarak arkadaşlarının bu mekanı eklemesini sağla.", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Paylaş butonu
                if let url = shareURL {
                    ShareLink(
                        item: url,
                        subject: Text(place.name),
                        message: Text(String(format: NSLocalizedString("%@ mekanını Pinly'e eklemek için bu linke dokun.", comment: ""), place.name))
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
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
            .navigationTitle(NSLocalizedString("Mekanı Paylaş", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
    }
}
