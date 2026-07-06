import SwiftUI
import UIKit

// MARK: - Rota Paylaşım Kartı (Instagram 4:5 formatı)
// Rota tamamlanınca ImageRenderer ile görsele çevrilip paylaşılır — büyüme kancası.

struct RouteShareCardView: View {
    let routeName: String
    let distanceText: String
    let durationText: String
    let stops: [String]
    let date: Date

    // Kart her modda koyu — dynamic tema renkleri yerine sabit açık tonlar
    private let mint = Color(red: 0.55, green: 0.76, blue: 0.63)   // açık çam
    private let pine = Color(red: 0.24, green: 0.47, blue: 0.35)   // çam

    private var dateText: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Üst: marka
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white, pine)
                Text("Pinly")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(dateText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            // Rota adı + ana metrik
            Text(NSLocalizedString("Rotayı Tamamladım! 🎉", comment: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(mint)
            Text(routeName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(.top, 4)

            HStack(spacing: 24) {
                ShareCardStat(value: distanceText, label: NSLocalizedString("Mesafe", comment: ""))
                if !durationText.isEmpty {
                    ShareCardStat(value: durationText, label: NSLocalizedString("Süre", comment: ""))
                }
                ShareCardStat(value: "\(stops.count)", label: NSLocalizedString("Durak", comment: ""))
            }
            .padding(.top, 20)

            // Duraklar
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stops.prefix(5).enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(pine)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            if index < min(stops.count, 5) - 1 {
                                Rectangle()
                                    .fill(mint.opacity(0.35))
                                    .frame(width: 2, height: 18)
                            }
                        }
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.bottom, index < min(stops.count, 5) - 1 ? 18 : 0)
                        Spacer()
                    }
                }
                if stops.count > 5 {
                    Text(String(format: NSLocalizedString("+ %lld durak daha", comment: ""), stops.count - 5))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        .padding(.leading, 38)
                }
            }
            .padding(.top, 28)

            Spacer()

            // Alt: çağrı
            HStack {
                Text(NSLocalizedString("Sen de rotanı çiz 🚶", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Text("pinly.app")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(mint)
            }
        }
        .padding(36)
        .frame(width: 540, height: 675)
        .background(
            ZStack {
                PinlyTheme.nightGradient
                // Dekoratif coral parıltı
                Circle()
                    .fill(pine.opacity(0.30))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .offset(x: 200, y: -260)
                Circle()
                    .fill(mint.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: -200, y: 280)
            }
        )
    }

    /// Kartı 1080×1350 px paylaşılabilir görsele çevirir
    @MainActor
    static func makeImage(
        routeName: String,
        distanceText: String,
        durationText: String,
        stops: [String],
        date: Date = Date()
    ) -> UIImage? {
        let view = RouteShareCardView(
            routeName: routeName,
            distanceText: distanceText,
            durationText: durationText,
            stops: stops,
            date: date
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct ShareCardStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}
