import SwiftUI
import SwiftData

// MARK: - Haftalık Rapor

struct WeeklyReportView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyStats) private var weeklyStats
    @Environment(\.notificationScheduling) private var notificationScheduling
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RouteHistory.date, order: .reverse) private var histories: [RouteHistory]

    /// Kullanıcı haftalık bildirim CTA'sına dokundu mu (izin isteme anı — FAZ 5.4)
    @AppStorage("pinly.weeklyNotifOptIn") private var weeklyNotifOptIn = false

    private var stats: WeeklyStats {
        weeklyStats.computeStats(places: placeStore.places, histories: histories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                        .padding(.bottom, stats.isEmpty ? 0 : -24)
                    if !stats.isEmpty {
                        statsOverlapCard
                    }
                    if !weeklyNotifOptIn {
                        notificationCTACard
                            .padding(.horizontal, 20)
                    }
                    if stats.isEmpty {
                        emptyState
                            .padding(.horizontal, 20)
                    } else {
                        if let cat = stats.topCategory {
                            topCategoryCard(cat)
                                .padding(.horizontal, 20)
                        }
                        if let district = stats.topDistrict {
                            topDistrictCard(district)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(PinlyTheme.groundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Başlık

    // Sage renkli header — "Bu Hafta" etiketi + kalın başlık,
    // altına taşan istatistik kartı.
    private var header: some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let range = "\(formatter.string(from: stats.weekStart)) – \(formatter.string(from: stats.weekEnd))"

        return VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Bu Hafta", comment: ""))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.8))
            Text(String(format: NSLocalizedString("%lld rota tamamladın", comment: ""), stats.routesCompleted))
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(range)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, stats.isEmpty ? 24 : 48)
        .background(
            ZStack {
                PinlyTheme.slate
                VStack {
                    Spacer()
                    Image(PinlyTheme.seigaihaLinesOnInk(colorScheme))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: 80)
                        .clipped()
                        .clipShape(WavyHorizonMask())
                        .opacity(0.3)
                }
            }
            .clipped()
            .allowsHitTesting(false)
        )
    }

    // MARK: - Taşan istatistik kartı

    private var statsOverlapCard: some View {
        HStack {
            weeklyStatColumn(value: stats.totalSteps > 0 ? "\(stats.totalSteps)" : "—", label: NSLocalizedString("Adım", comment: ""))
            Spacer()
            weeklyStatColumn(value: stats.totalDistanceMeters > 0 ? stats.formattedDistance : "—", label: NSLocalizedString("Mesafe", comment: ""))
            Spacer()
            weeklyStatColumn(value: "\(placeStore.places.filter { $0.isVisited }.count)", label: NSLocalizedString("Toplam Ziyaret", comment: ""))
            Spacer()
            weeklyStatColumn(value: "\(stats.routesCompleted)", label: NSLocalizedString("Rota", comment: ""), valueColor: PinlyTheme.gold)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PinlyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        )
        .padding(.horizontal, 20)
    }

    private func weeklyStatColumn(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Bildirim CTA (izin isteme anı — FAZ 5.4)

    private var notificationCTACard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PinlyTheme.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(PinlyTheme.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Haftalık özetini kaçırma", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(NSLocalizedString("Her Pazar 09:00'da bildirim al.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                notificationScheduling.requestWeeklyNotification()
                weeklyNotifOptIn = true
            } label: {
                Text(NSLocalizedString("Aç", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PinlyTheme.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PinlyTheme.primary))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PinlyTheme.fillMuted)
        )
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

