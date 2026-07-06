import SwiftUI
import SwiftData

// MARK: - Profil İstatistikleri

struct ProfileStatsView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.badges) private var badgeService
    @Query(sort: \RouteHistory.date, order: .reverse) private var histories: [RouteHistory]

    private var totalDistanceKm: Double {
        histories.reduce(0) { $0 + $1.totalDistanceMeters } / 1000
    }
    private var totalSteps: Int {
        histories.reduce(0) { $0 + $1.stepCount }
    }
    private var totalDuration: TimeInterval {
        histories.reduce(0) { $0 + $1.durationSeconds }
    }
    private var visitedCount: Int {
        placeStore.places.filter { $0.isVisited }.count
    }
    private var topCategory: PlaceCategory? {
        let cats = placeStore.places.map { PlaceCategory.from($0.category) }
        guard !cats.isEmpty else { return nil }
        return Dictionary(grouping: cats, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key
    }
    private var topDistrict: String? {
        let districts = placeStore.places.map(\.district).filter { !$0.isEmpty }
        guard !districts.isEmpty else { return nil }
        return Dictionary(grouping: districts, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key
    }
    private var averageRating: Double? {
        let ratings = placeStore.places.compactMap { $0.userRating }
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    private var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = totalDuration >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: totalDuration) ?? "0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Hero kart — yürüyüş toplamları
                    VStack(spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Toplam Yürüyüş", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.75))
                                Text(String(format: "%.1f km", totalDistanceKm))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                            }
                            Spacer()
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        HStack(spacing: 0) {
                            HeroStat(value: "\(histories.count)", label: NSLocalizedString("Rota", comment: ""))
                            HeroStat(value: totalSteps.formatted(), label: NSLocalizedString("Adım", comment: ""))
                            HeroStat(value: formattedDuration, label: NSLocalizedString("Süre", comment: ""))
                        }
                    }
                    .padding(22)
                    .background(PinlyTheme.heroGradient)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 5)

                    // Mekan istatistikleri
                    HStack(spacing: 0) {
                        StatChip(value: "\(placeStore.places.count)",
                                 label: NSLocalizedString("Mekan", comment: ""),
                                 icon: "mappin.circle.fill", color: PinlyTheme.primary)
                        StatChip(value: "\(visitedCount)",
                                 label: NSLocalizedString("Ziyaret", comment: ""),
                                 icon: "checkmark.circle.fill", color: PinlyTheme.primaryWarm)
                        StatChip(value: "\(badgeService.consecutiveDays)",
                                 label: NSLocalizedString("Gün Serisi", comment: ""),
                                 icon: "flame.fill", color: PinlyTheme.accent)
                        StatChip(value: "\(badgeService.unlockedBadges.count)",
                                 label: NSLocalizedString("Rozet", comment: ""),
                                 icon: "trophy.fill", color: PinlyTheme.gold)
                    }
                    .pinlyCard()

                    // Öne çıkanlar
                    VStack(spacing: 0) {
                        if let cat = topCategory {
                            HighlightRow(
                                icon: cat.icon, color: cat.color,
                                title: NSLocalizedString("En Sevdiğin Kategori", comment: ""),
                                value: cat.localizedName
                            )
                        }
                        if let district = topDistrict {
                            Divider().padding(.leading, 56)
                            HighlightRow(
                                icon: "building.2.fill", color: PinlyTheme.slate,
                                title: NSLocalizedString("En Çok Mekan", comment: ""),
                                value: district
                            )
                        }
                        if let avg = averageRating {
                            Divider().padding(.leading, 56)
                            HighlightRow(
                                icon: "star.fill", color: PinlyTheme.gold,
                                title: NSLocalizedString("Ortalama Puanın", comment: ""),
                                value: String(format: "%.1f / 5", avg)
                            )
                        }
                        if topCategory == nil && topDistrict == nil && averageRating == nil {
                            Text(NSLocalizedString("Mekan ekledikçe istatistiklerin burada birikecek", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 20)
                        }
                    }
                    .pinlyCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PinlyTheme.ground)
            .navigationTitle(NSLocalizedString("İstatistiklerim", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Alt Bileşenler

private struct HeroStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HighlightRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 10)
    }
}
