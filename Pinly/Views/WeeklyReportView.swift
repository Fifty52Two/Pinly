import SwiftUI
import SwiftData

// MARK: - Haftalık Rapor

struct WeeklyReportView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyStats) private var weeklyStats
    @Query(sort: \RouteHistory.date, order: .reverse) private var histories: [RouteHistory]

    private var stats: WeeklyStats {
        weeklyStats.computeStats(places: placeStore.places, histories: histories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateHeader
                    if stats.isEmpty {
                        emptyState
                    } else {
                        statsGrid
                        if let cat = stats.topCategory {
                            topCategoryCard(cat)
                        }
                        if let district = stats.topDistrict {
                            topDistrictCard(district)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
                .padding(.horizontal, 20)
            }
            .background(PinlyTheme.groundGradient)
            .navigationTitle("Haftalık Rapor")
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

    // MARK: - Tarih başlığı

    private var dateHeader: some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let range = "\(formatter.string(from: stats.weekStart)) – \(formatter.string(from: stats.weekEnd))"
        return Text(range)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Boş durum

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("Bu hafta henüz rota tamamlanmadı", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("Bir rota tamamladığında burada istatistiklerini görebilirsin.", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - İstatistik kartları

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            WeeklyStatCard(
                icon: "figure.walk.circle.fill",
                color: PinlyTheme.primary,
                value: stats.totalSteps > 0 ? "\(stats.totalSteps)" : "—",
                label: NSLocalizedString("Adım", comment: "")
            )
            WeeklyStatCard(
                icon: "arrow.triangle.turn.up.right.circle.fill",
                color: PinlyTheme.success,
                value: stats.totalDistanceMeters > 0 ? stats.formattedDistance : "—",
                label: NSLocalizedString("Mesafe", comment: "")
            )
            WeeklyStatCard(
                icon: "mappin.circle.fill",
                color: PinlyTheme.primaryWarm,
                value: "\(placeStore.places.filter { $0.isVisited }.count)",
                label: NSLocalizedString("Toplam Ziyaret", comment: "")
            )
            WeeklyStatCard(
                icon: "map.circle.fill",
                color: .teal,
                value: "\(stats.routesCompleted)",
                label: NSLocalizedString("Rota", comment: "")
            )
        }
    }

    // MARK: - En çok kategori

    private func topCategoryCard(_ cat: PlaceCategory) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(cat.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: cat.icon)
                    .font(.title2)
                    .foregroundColor(cat.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("En Çok Kaydedilen", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(cat.localizedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
    }

    // MARK: - En çok bölge

    private func topDistrictCard(_ district: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PinlyTheme.warning.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(PinlyTheme.warning)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("En Çok Ziyaret Edilen Bölge", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(district)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
    }
}

// MARK: - İstatistik Kart

private struct WeeklyStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
        )
    }
}
