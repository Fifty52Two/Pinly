import SwiftUI
import SwiftData

// MARK: - Rota Geçmişi

struct RouteHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RouteHistory.date, order: .reverse) private var histories: [RouteHistory]

    var body: some View {
        NavigationStack {
            Group {
                if histories.isEmpty {
                    emptyState
                } else {
                    List(histories) { history in
                        RouteHistoryRow(history: history)
                            .listRowBackground(PinlyTheme.surface)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Rota Geçmişi", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("Henüz rota tamamlanmadı", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
            Text(NSLocalizedString("Bir rota tamamladığında burada görünecek.", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Satır

private struct RouteHistoryRow: View {
    let history: RouteHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(history.routeName)
                    .font(.headline)
                Spacer()
                Text(history.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Mekan listesi
            if !history.placeNames.isEmpty {
                Text(history.placeNames.joined(separator: " → "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // İstatistikler
            HStack(spacing: 0) {
                HistoryStatPill(icon: "figure.walk", value: history.formattedDistance, color: .blue)
                HistoryStatPill(icon: "clock", value: history.formattedDuration, color: .green)
                if history.stepCount > 0 {
                    HistoryStatPill(icon: "shoeprints.fill", value: "\(history.stepCount) adım", color: .orange)
                }
                if history.averageSpeedKmh > 0 {
                    HistoryStatPill(icon: "speedometer", value: String(format: "%.1f km/s", history.averageSpeedKmh), color: .purple)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HistoryStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .padding(.trailing, 6)
    }
}
