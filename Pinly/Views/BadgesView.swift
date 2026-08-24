import SwiftUI

// MARK: - Rozetler Ekranı

struct BadgesView: View {
    @Environment(\.badges) private var badgeService
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var unlocked: Set<Badge> { badgeService.unlockedBadges }

    private var total: Int { Badge.allCases.count }
    private var earned: Int { unlocked.count }
    private var fraction: Double { Double(earned) / Double(total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    badgeGrid
                        .padding(.top, 26)
                        .padding(.bottom, 40)
                }
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
                            .foregroundStyle(.secondary, PinlyTheme.surface)
                    }
                }
            }
            // Nav bar arkaplanı bilinçli olarak saydam (yukarıda .toolbarBackground(.hidden,...))
            // — bu ekranın kendi header'ı sistem large-title'ın yerine geçiyor (bkz. mockup notu).
            // Header .ignoresSafeArea(edges: .top) ile o saydam alanı da kendi zeminiyle dolduruyor;
            // aksi halde X butonunun arkasında sunan ekran (ProfileTab) sızıp başlığın "kesik" görünmesine yol açıyordu.
        }
    }

    // MARK: - Başlık

    // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki rozet header'ı — kart
    // yüzeyi + gerçek seigaiha PNG dokusu + büyük başlık, sistem large-title'ın yerine
    // (birebir). İlerleme çubuğu mockup'ta yok ama mevcut işlevsellik korunuyor — başlık
    // altına küçük bir aksesuar olarak eklendi (görsel restyle, davranış aynı).
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Rozetlerin", comment: ""))
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)
            Text(String(format: NSLocalizedString("%lld/%lld rozet kazanıldı", comment: ""), earned, total))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary.opacity(0.65))
            // Kilitli/kazanılmış rozet oranı — sabit yükseklikli iki katmanlı kapsül,
            // dolu kısım GeometryReader yerine leading-anchor scaleEffect ile daraltılıyor
            // (genişlik hesabı için ayrı bir layout geçişi gerekmiyor).
            ZStack(alignment: .leading) {
                Capsule().fill(PinlyTheme.fillMuted)
                Capsule().fill(PinlyTheme.gold)
                    .scaleEffect(x: max(0.02, fraction), y: 1, anchor: .leading)
                    .animation(.spring(response: 0.4), value: fraction)
            }
            .frame(height: 6)
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .leading) {
                PinlyTheme.surface
                Image(PinlyTheme.seigaihaLinesOnPaper(colorScheme))
                    .resizable()
                    .scaledToFill()
                    .opacity(0.5)
                    .allowsHitTesting(false)
                LinearGradient(
                    colors: [PinlyTheme.surface.opacity(0.92), PinlyTheme.surface.opacity(0.75), PinlyTheme.surface.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipped()
        )
        // Header, saydam nav bar'ın arkasını da kendi zeminiyle dolduruyor (X butonu üstünde
        // yüzüyor) — sistem large-title'ın birebir yerine geçen mockup tasarımı bu şekilde
        // tamamlanıyor. Sabit .frame(height:) kaldırıldı: büyük Dynamic Type'ta içerik artık
        // kırpılmak yerine header'ı doğal biçimde büyütüyor.
        .ignoresSafeArea(edges: .top)
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
        // Claude Design mockup'ındaki rozet hücresi — kazanılan rozetler dolu renkli
        // daire + beyaz glif + gölge, kilitli olanlar nötr gri daire + asma kilit
        // (kart zemini yok, madalyonlar doğrudan grid üstünde — birebir).
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badgeColor : PinlyTheme.fillMuted)
                    .frame(width: 60, height: 60)
                    .shadow(color: isUnlocked ? badgeColor.opacity(0.35) : .clear, radius: 6, y: 3)
                if isUnlocked {
                    Image(systemName: badge.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "lock")
                        .font(.title3)
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
                Text(badgeService.progressText(for: badge, placeStore: placeStore))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // Ham SwiftUI sistem renkleri (.yellow/.purple/.blue...) seigaiha paletiyle
    // ÇAKIŞIYORDU — CLAUDE.md "renkler Theme'den alınır, hardcode edilmez" kuralının
    // eski bir ihlaliydi, mockup'taki muted altın/sage tonlarıyla hiç örtüşmüyordu.
    // Artık paletin 5 token'ına (primary/primaryWarm/accent/gold/slate) eşleniyor.
    private var badgeColor: Color {
        switch badge.color {
        case "yellow":  return PinlyTheme.gold
        case "orange":  return PinlyTheme.accent
        case "purple":  return PinlyTheme.primaryWarm
        case "red":     return PinlyTheme.accent
        case "green":   return PinlyTheme.success
        case "teal":    return PinlyTheme.slate
        case "indigo":  return PinlyTheme.primary
        case "pink":    return PinlyTheme.accent
        case "cyan":    return PinlyTheme.primaryWarm
        default:        return PinlyTheme.primary
        }
    }
}

// MARK: - Banner (HomeView overlay'i için)

struct BadgeBannerView: View {
    let badge: Badge
    let onDismiss: () -> Void

    @State private var visible = false

    // Ham SwiftUI sistem renkleri (.yellow/.purple/.blue...) seigaiha paletiyle
    // ÇAKIŞIYORDU — CLAUDE.md "renkler Theme'den alınır, hardcode edilmez" kuralının
    // eski bir ihlaliydi, mockup'taki muted altın/sage tonlarıyla hiç örtüşmüyordu.
    // Artık paletin 5 token'ına (primary/primaryWarm/accent/gold/slate) eşleniyor.
    private var badgeColor: Color {
        switch badge.color {
        case "yellow":  return PinlyTheme.gold
        case "orange":  return PinlyTheme.accent
        case "purple":  return PinlyTheme.primaryWarm
        case "red":     return PinlyTheme.accent
        case "green":   return PinlyTheme.success
        case "teal":    return PinlyTheme.slate
        case "indigo":  return PinlyTheme.primary
        case "pink":    return PinlyTheme.accent
        case "cyan":    return PinlyTheme.primaryWarm
        default:        return PinlyTheme.primary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: badge.icon)
                    .font(.title3)
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
        )
        .padding(.horizontal, 16)
        .offset(y: visible ? 0 : -120)
        .opacity(visible ? 1 : 0)
        .onAppear {
            HapticPlayer.badgeUnlocked()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) { visible = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        }
    }
}
