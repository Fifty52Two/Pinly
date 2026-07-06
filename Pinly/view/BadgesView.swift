import SwiftUI

// MARK: - Rozetler Ekranı

struct BadgesView: View {
    @Environment(\.badges) private var badgeService
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var unlocked: Set<Badge> { badgeService.unlockedBadges }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    progressBar
                    badgeGrid
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle(NSLocalizedString("Rozetler", comment: ""))
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

    // MARK: - İlerleme çubuğu

    private var progressBar: some View {
        let total    = Badge.allCases.count
        let earned   = unlocked.count
        let fraction = Double(earned) / Double(total)

        return VStack(spacing: 8) {
            HStack {
                Text(String(format: NSLocalizedString("%lld/%lld rozet kazanıldı", comment: ""), earned, total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow)
                        .frame(width: geo.size.width * fraction, height: 8)
                        .animation(.spring(response: 0.4), value: fraction)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Rozet grid

    private var badgeGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Badge.allCases, id: \.rawValue) { badge in
                BadgeCell(badge: badge, isUnlocked: unlocked.contains(badge), placeStore: placeStore)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Rozet Hücresi

private struct BadgeCell: View {
    @Environment(\.badges) private var badgeService
    let badge: Badge
    let isUnlocked: Bool
    let placeStore: PlaceStore

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badgeColor.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                if isUnlocked {
                    Image(systemName: badge.icon)
                        .font(.system(size: 26))
                        .foregroundColor(badgeColor)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            Text(badge.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if !isUnlocked {
                Text(badge.progressText(placeStore: placeStore, badges: badgeService))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isUnlocked ? badgeColor.opacity(0.06) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isUnlocked ? badgeColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var badgeColor: Color {
        switch badge.color {
        case "yellow":  return .yellow
        case "orange":  return .orange
        case "purple":  return .purple
        case "red":     return .red
        case "green":   return .green
        case "teal":    return .teal
        case "indigo":  return .indigo
        case "pink":    return .pink
        case "cyan":    return .cyan
        default:        return .blue
        }
    }
}

// MARK: - Banner (HomeView overlay'i için)

struct BadgeBannerView: View {
    let badge: Badge
    let onDismiss: () -> Void

    @State private var visible = false

    private var badgeColor: Color {
        switch badge.color {
        case "yellow":  return .yellow
        case "orange":  return .orange
        case "purple":  return .purple
        case "red":     return .red
        case "green":   return .green
        case "teal":    return .teal
        case "indigo":  return .indigo
        case "pink":    return .pink
        case "cyan":    return .cyan
        default:        return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: badge.icon)
                    .font(.system(size: 20))
                    .foregroundColor(badgeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Yeni Rozet!", comment: ""))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text(badge.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(badge.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .padding(.horizontal, 16)
        .offset(y: visible ? 0 : -120)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) { visible = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        }
    }
}
