import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct SharePlaceView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss

    private var shareURL: URL? { PlaceImporter.buildURL(for: place) }
    private var qrImage: UIImage? {
        guard let url = shareURL else { return nil }
        return generateQR(from: url.absoluteString)
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
                                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray5))
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

    // MARK: - QR Generation

    private func generateQR(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
