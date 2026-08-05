import SwiftUI
import MapKit
// MARK: - Navigation Banner

struct NavigationBanner: View {
    let instruction: String
    let distance: String
    let stopIndex: Int
    let totalStops: Int
    let completionPct: Double

    var body: some View {
        // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (29 · Navigasyon) dolu
        // navy talimat kartı — yarı saydam materyal + renkli ikon kutusu yerine
        // (birebir); "Durak x/y" etiketi mockup'ta yok ama mevcut işlevsellik,
        // altına küçük bir aksesuar olarak korunuyor.
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title2)
                    .foregroundColor(PinlyTheme.cream)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("Durak %lld / %lld", comment: ""), stopIndex, totalStops))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(PinlyTheme.cream.opacity(0.6))
                    Text(instruction.isEmpty ? NSLocalizedString("Devam edin", comment: "") : instruction)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    if !distance.isEmpty {
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(PinlyTheme.cream.opacity(0.6))
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                    Rectangle()
                        .fill(PinlyTheme.cream)
                        .frame(width: geo.size.width * CGFloat(completionPct), height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionPct)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(PinlyTheme.navy)
    }
}


// MARK: - Route Overview Panel

struct RouteOverviewPanel: View {
    let totalDistance: Double
    let totalTime: TimeInterval
    let stopCount: Int

    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: totalDistance)
    }

    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = totalTime >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: max(60, totalTime)) ?? ""
    }

    var body: some View {
        // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (24 · Rota özeti)
        // ikonsuz, büyük rakamlı istatistik dizilimi (birebir).
        HStack(spacing: 0) {
            RouteStatItem(value: formattedDistance, label: NSLocalizedString("Mesafe", comment: ""))
            RouteStatItem(value: formattedTime, label: NSLocalizedString("Süre", comment: ""))
            RouteStatItem(value: "\(stopCount)", label: NSLocalizedString("Mekan", comment: ""))
        }
    }
}

struct RouteStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.body, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
