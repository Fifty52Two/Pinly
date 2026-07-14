import SwiftUI
import MapKit
// MARK: - Arrival Banner

struct ArrivalBannerView: View {
    let placeName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Varıldı!", comment: ""))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(placeName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
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

struct RouteCompletionOverlay: View {
    let totalDistance: Double
    let stopsVisited: Int
    let totalStops: Int
    var onShareCard: (() -> Void)? = nil
    let onDismiss: () -> Void

    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .full
        return formatter.string(fromDistance: totalDistance)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "flag.pattern.checkered.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(PinlyTheme.primary)
                    .symbolRenderingMode(.hierarchical)
                Text(NSLocalizedString("Rota Tamamlandı!", comment: ""))
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 14) {
                    CompletionStatRow(icon: "figure.walk", label: NSLocalizedString("Toplam Mesafe", comment: ""), value: formattedDistance)
                    CompletionStatRow(icon: "checkmark.circle.fill", label: NSLocalizedString("Ziyaret Edilen", comment: ""), value: "\(stopsVisited) / \(totalStops)")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )

                VStack(spacing: 10) {
                    if let share = onShareCard {
                        Button(action: share) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(NSLocalizedString("Başarını Paylaş", comment: ""))
                            }
                        }
                        .buttonStyle(PinlyPrimaryButtonStyle())
                    }
                    Button {
                        onDismiss()
                    } label: {
                        Text(NSLocalizedString("Haritaya Dön", comment: ""))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 24)
        }
    }
}

struct CompletionStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(PinlyTheme.primary)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
