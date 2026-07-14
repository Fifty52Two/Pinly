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
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(PinlyTheme.primary)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("Durak %lld / %lld", comment: ""), stopIndex, totalStops))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(PinlyTheme.primary)
                    Text(instruction.isEmpty ? NSLocalizedString("Devam edin", comment: "") : instruction)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    if !distance.isEmpty {
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(PinlyTheme.fillMuted)
                        .frame(height: 3)
                    Rectangle()
                        .fill(PinlyTheme.primary)
                        .frame(width: geo.size.width * CGFloat(completionPct), height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionPct)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(.regularMaterial)
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
        HStack(spacing: 0) {
            RouteStatItem(value: formattedDistance, label: NSLocalizedString("Toplam Yürüyüş", comment: ""), icon: "figure.walk")
            Divider().frame(height: 32)
            RouteStatItem(value: formattedTime, label: NSLocalizedString("Tahmini Süre", comment: ""), icon: "clock")
            Divider().frame(height: 32)
            RouteStatItem(value: "\(stopCount)", label: NSLocalizedString("Durak", comment: ""), icon: "mappin.circle.fill")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
    }
}

struct RouteStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(PinlyTheme.primary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
