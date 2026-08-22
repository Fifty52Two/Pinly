import SwiftUI
import MapKit
// MARK: - Arrival Banner

struct ArrivalBannerView: View {
    let placeName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(PinlyTheme.onAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Varıldı!", comment: ""))
                    .font(.caption)
                    .foregroundColor(PinlyTheme.onAccent.opacity(0.8))
                Text(placeName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(PinlyTheme.onAccent)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PinlyTheme.success)
        )
        .padding(.horizontal, 16)
    }
}


// MARK: - Route Completion Overlay

/// Wow #1 — rota tamamlama sekansı (specs/FAZ6_UI_YON.md):
/// konfeti (zaten var) → istatistikler SIRAYLA belirir (km → dk → adım → ziyaret,
/// her biri 0.15sn arayla spring + `contentTransition(.numericText())` ile 0'dan
/// sayarak) → son istatistikten 0.6sn sonra hikaye/paylaşım kartı alttan spring
/// ile yükselir (hafif 3D "masaya kart koyma" hissi) → o anda başarı haptic çifti.
/// Reduce Motion açıksa sayaçlar animasyonsuz direkt final değere gider, kart
/// sadece fade ile gelir (spring/rotation yok) — haptic yine de çalar (motion değil).
struct RouteCompletionOverlay: View {
    let totalDistance: Double
    let totalTimeSeconds: TimeInterval
    let stepCount: Int
    let stopsVisited: Int
    let totalStops: Int
    var onShareMemory: (() -> Void)? = nil
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // Kutlama animasyon durumu
    @State private var appeared = false
    @State private var revealedStatCount = 0
    @State private var displayedDistance: Double = 0
    @State private var displayedDurationSeconds: TimeInterval = 0
    @State private var displayedSteps: Int = 0
    @State private var displayedVisited: Int = 0
    @State private var shareCardAppeared = false

    private let statCount = 4
    private let statStartDelay = 0.3
    private let statStagger = 0.15

    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .full
        return formatter.string(fromDistance: displayedDistance)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = displayedDurationSeconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: displayedDurationSeconds) ?? "0"
    }

    var formattedSteps: String {
        displayedSteps.formatted()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // Konfeti — dimmer üstünde, kartın altında
            if appeared {
                ConfettiView()
            }

            VStack(spacing: 24) {
                // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki rota tamamlandı
                // rozeti — dolu sage dairesi + kalın check glifi (önceki hiyerarşik
                // bayrak ikonunun yerine, birebir).
                ZStack {
                    Circle()
                        .fill(PinlyTheme.success)
                        .frame(width: 84, height: 84)
                        .shadow(color: PinlyTheme.success.opacity(0.35), radius: 12, y: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(PinlyTheme.onAccent)
                        .symbolEffect(.bounce, value: reduceMotion ? false : appeared)
                }
                Text(NSLocalizedString("Rota Tamamlandı!", comment: ""))
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: 28) {
                    statColumn(index: 0, label: NSLocalizedString("Toplam Mesafe", comment: ""), value: formattedDistance)
                    statColumn(index: 1, label: NSLocalizedString("Süre", comment: ""), value: formattedDuration)
                    statColumn(index: 2, label: NSLocalizedString("Adım", comment: ""), value: formattedSteps, valueColor: PinlyTheme.gold)
                    statColumn(index: 3, label: NSLocalizedString("Ziyaret Edilen", comment: ""), value: "\(displayedVisited) / \(totalStops)")
                }

                VStack(spacing: 10) {
                    if let share = onShareMemory {
                        shareTeaserCard(action: share)
                    }
                    Button {
                        onDismiss()
                    } label: {
                        Text(NSLocalizedString("Haritaya Dön", comment: ""))
                            .fontWeight(.bold)
                            .foregroundColor(PinlyTheme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                // Mockup'ın alt bandındaki gerçek seigaiha PNG dokusu —
                                // önceki turda hiç eklenmemişti, düz primary'ydi.
                                ZStack {
                                    PinlyTheme.primary
                                    GeometryReader { geo in
                                        Image(PinlyTheme.seigaihaLinesOnInk(colorScheme))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.height)
                                            .clipShape(Rectangle())
                                    }
                                    .opacity(0.35)
                                }
                                .clipShape(Capsule())
                            )
                    }
                    .opacity(shareCardAppeared ? 1 : 0)
                    .accessibilityHidden(!shareCardAppeared)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(PinlyTheme.surface)
            )
            .padding(.horizontal, 24)
            .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.85))
            .opacity(appeared ? 1 : 0)
        }
        .onAppear(perform: runSequence)
    }

    // Claude Design mockup'ındaki üçlü sütun istatistik dizilimi — ikon+etiket+değer
    // satırı yerine büyük rakam + küçük etiket, yan yana (birebir).
    @ViewBuilder
    private func statColumn(index: Int, label: String, value: String, valueColor: Color = .primary) -> some View {
        let revealed = revealedStatCount > index
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
        .opacity(revealed ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (revealed ? 0 : 8))
        .accessibilityHidden(!revealed)
    }

    @ViewBuilder
    private func shareTeaserCard(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PinlyTheme.primary.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundColor(PinlyTheme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Hikayeni Paylaş", comment: ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(NSLocalizedString("Bu anıyı hikaye ya da gönderi olarak paylaş", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("Hikayeni Paylaş", comment: ""))
        .accessibilityHint(NSLocalizedString("Bu anıyı hikaye ya da gönderi olarak paylaş", comment: ""))
        .accessibilityHidden(!shareCardAppeared)
        .opacity(shareCardAppeared ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (shareCardAppeared ? 0 : 40))
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (shareCardAppeared ? 0 : -8)),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.4
        )
    }

    private func runSequence() {
        if reduceMotion {
            appeared = true
            revealedStatCount = statCount
            displayedDistance = totalDistance
            displayedDurationSeconds = totalTimeSeconds
            displayedSteps = stepCount
            displayedVisited = stopsVisited
            withAnimation(.easeInOut(duration: 0.25)) {
                shareCardAppeared = true
            }
            HapticPlayer.routeCompleted()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            appeared = true
        }

        for i in 0..<statCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + statStartDelay + Double(i) * statStagger) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    revealedStatCount = i + 1
                    switch i {
                    case 0: displayedDistance = totalDistance
                    case 1: displayedDurationSeconds = totalTimeSeconds
                    case 2: displayedSteps = stepCount
                    case 3: displayedVisited = stopsVisited
                    default: break
                    }
                }
            }
        }

        let lastStatDelay = statStartDelay + Double(statCount - 1) * statStagger
        let cardDelay = lastStatDelay + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + cardDelay) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                shareCardAppeared = true
            }
            HapticPlayer.routeCompleted()
        }
    }
}
