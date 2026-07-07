import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var storedTheme = "light"

    private var t: ThemeColors { ThemeColors.make(storedTheme) }
    private var isLight: Bool { storedTheme == "light" }

    // MARK: - Computed stats

    private var totalPlaces: Int { placeStore.places.count }

    private var totalVisits: Int { placeStore.places.reduce(0) { $0 + $1.visitCount } }

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }

    private var topCategory: String? {
        let counts = Dictionary(grouping: placeStore.places, by: { $0.category })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var averageRating: Double? {
        let rated = placeStore.places.compactMap { $0.userRating.map { Double($0) } }
        guard !rated.isEmpty else { return nil }
        return rated.reduce(0, +) / Double(rated.count)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        statsGrid
                        themeSection
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.subtitle)
                    .padding(10)
                    .background(Circle().fill(t.card))
                    .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("PROFİL")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundColor(t.title)

            Spacer()

            Circle().fill(Color.clear).frame(width: 36, height: 36) // balance
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("İSTATİSTİKLER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(t.subtitle.opacity(0.5))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    value: "\(totalPlaces)",
                    label: "Kayıtlı Mekan",
                    icon: "mappin.circle.fill",
                    t: t
                )
                StatCard(
                    value: "\(visitedCount)",
                    label: "Ziyaret Edildi",
                    icon: "checkmark.circle.fill",
                    t: t
                )
                StatCard(
                    value: "\(totalVisits)",
                    label: "Toplam Ziyaret",
                    icon: "figure.walk.circle.fill",
                    t: t
                )
                if let avg = averageRating {
                    StatCard(
                        value: String(format: "%.1f", avg),
                        label: "Ort. Puan",
                        icon: "star.circle.fill",
                        t: t
                    )
                } else {
                    StatCard(
                        value: "—",
                        label: "Ort. Puan",
                        icon: "star.circle.fill",
                        t: t
                    )
                }
            }

            if let cat = topCategory {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(PlaceStyle.color(for: cat).opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: PlaceStyle.icon(for: cat))
                            .font(.system(size: 18))
                            .foregroundColor(PlaceStyle.color(for: cat))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("En çok kayıt")
                            .font(.system(size: 11))
                            .foregroundColor(t.subtitle)
                        Text(cat)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(t.title)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(t.card)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GÖRÜNÜM")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(t.subtitle.opacity(0.5))

            HStack(spacing: 12) {
                themeOption(
                    label: "Ivory & Gilded",
                    sublabel: "Açık tema",
                    icon: "sun.max.fill",
                    isSelected: isLight,
                    onTap: { storedTheme = "light" }
                )
                themeOption(
                    label: "Obsidian & Gilt",
                    sublabel: "Koyu tema",
                    icon: "moon.fill",
                    isSelected: !isLight,
                    onTap: { storedTheme = "dark" }
                )
            }
        }
    }

    private func themeOption(label: String, sublabel: String, icon: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? t.buttonText : t.subtitle)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(isSelected ? t.accent : t.card))
                    .overlay(Circle().stroke(isSelected ? Color.clear : t.cardBorder, lineWidth: 1))
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? t.primary : t.title)
                        .multilineTextAlignment(.center)
                    Text(sublabel)
                        .font(.system(size: 10))
                        .foregroundColor(t.subtitle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? t.accent.opacity(0.1) : t.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? t.accent.opacity(0.5) : t.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UYGULAMA")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(t.subtitle.opacity(0.5))

            VStack(spacing: 0) {
                aboutRow(icon: "safari.fill", label: "Curator Routes", value: "v1.0")
                Divider().background(t.separator).padding(.leading, 52)
                aboutRow(icon: "mappin.and.ellipse", label: "Veri", value: "Sadece cihazda")
                Divider().background(t.separator).padding(.leading, 52)
                aboutRow(icon: "lock.fill", label: "Gizlilik", value: "Konum paylaşılmaz")
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(t.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
            )
        }
    }

    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(t.primary)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(t.title)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(t.subtitle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let t: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(t.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(t.title)
                    .tracking(-0.5)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(t.subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.cardBorder, lineWidth: 1))
        )
    }
}
