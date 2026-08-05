import SwiftUI

struct SharePlaceView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.routeURLCoding) private var routeURLCoding
    @Environment(\.qrCodeGenerator) private var qrCodeGenerator

    @State private var showCopiedConfirmation = false

    private var shareURL: URL? { routeURLCoding.buildURL(for: place) }
    private var qrImage: UIImage? {
        guard let url = shareURL else { return nil }
        return qrCodeGenerator.generateQRCode(from: url.absoluteString)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (23 · Mekan
                // paylaş) dolu primary kart — mekan adı + QR kodu birlikte, gerçek
                // seigaiha dokusu üstünde (birebir).
                VStack(spacing: 18) {
                    Text(place.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    if let qr = qrImage {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Image(systemName: "qrcode")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .padding(26)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        PinlyTheme.primary
                        Image("SeigaihaPattern")
                            .resizable()
                            .scaledToFill()
                            .opacity(0.3)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.top, 8)

                Text(NSLocalizedString("QR kodu okutarak veya linki paylaşarak arkadaşlarının bu mekanı eklemesini sağla.", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Link Kopyala + Paylaş — mockup'taki ikili buton dizilimi (birebir);
                // Instagram ayrıca listelenmedi, sistem paylaşım sayfası zaten içeriyor.
                HStack(spacing: 10) {
                    Button {
                        if let url = shareURL {
                            UIPasteboard.general.string = url.absoluteString
                            showCopiedConfirmation = true
                        }
                    } label: {
                        Text(showCopiedConfirmation
                             ? NSLocalizedString("Kopyalandı", comment: "")
                             : NSLocalizedString("Link Kopyala", comment: ""))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(PinlyTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(shareURL == nil)

                    if let url = shareURL {
                        ShareLink(
                            item: url,
                            subject: Text(place.name),
                            message: Text(String(format: NSLocalizedString("%@ mekanını Pinly'e eklemek için bu linke dokun.", comment: ""), place.name))
                        ) {
                            Text(NSLocalizedString("Paylaş", comment: ""))
                                .fontWeight(.semibold)
                                .foregroundColor(PinlyTheme.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(PinlyTheme.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(PinlyTheme.groundGradient)
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
