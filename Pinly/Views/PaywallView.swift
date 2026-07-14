import SwiftUI

struct PaywallView: View {
    let onDismiss: () -> Void
    @Environment(\.entitlements) private var entitlements

    // TODO: Apple Developer alınınca RevenueCat ile değişecek:
    // @State private var offering: Offering? = nil
    // @State private var selectedPackage: Package? = nil
    @State private var selectedPlan: PlanOption = .yearly
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {

            // Başlık
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PinlyTheme.primary.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 32))
                        .foregroundColor(PinlyTheme.primary)
                }
                .padding(.top, 32)

                Text(NSLocalizedString("Mekan Limitine Ulaştın", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(format: NSLocalizedString("Ücretsiz planda en fazla %lld mekan kaydedebilirsin.\nSınırsız mekan için Pro'ya geç.", comment: ""), entitlements.freeLimit))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Fayda listesi
            VStack(alignment: .leading, spacing: 14) {
                ProFeatureRow(icon: "mappin.and.ellipse", color: PinlyTheme.primary,
                              title: NSLocalizedString("Sınırsız Mekan", comment: ""),
                              subtitle: NSLocalizedString("İstediğin kadar mekan kaydet", comment: ""),
                              badge: nil)
                ProFeatureRow(icon: "map.fill", color: PinlyTheme.primaryWarm,
                              title: NSLocalizedString("Sınırsız Rota", comment: ""),
                              subtitle: NSLocalizedString("Dilediğin kadar rota oluştur", comment: ""),
                              badge: nil)
                ProFeatureRow(icon: "wifi.slash", color: PinlyTheme.accent,
                              title: NSLocalizedString("Çevrimdışı Harita", comment: ""),
                              subtitle: NSLocalizedString("İnternetsiz de çalışır", comment: ""),
                              badge: NSLocalizedString("Yakında", comment: ""))
                ProFeatureRow(icon: "person.2.fill", color: PinlyTheme.slate,
                              title: NSLocalizedString("Grup Rotaları", comment: ""),
                              subtitle: NSLocalizedString("Arkadaşlarınla birlikte planla", comment: ""),
                              badge: NSLocalizedString("Yakında", comment: ""))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 8)

            Spacer()

            // Plan seçici
            VStack(spacing: 10) {
                PlanOptionButton(
                    label: NSLocalizedString("Yıllık", comment: ""),
                    price: "$39.99 / yıl",
                    badge: NSLocalizedString("%33 Tasarruf", comment: ""),
                    isSelected: selectedPlan == .yearly
                ) { selectedPlan = .yearly }

                PlanOptionButton(
                    label: NSLocalizedString("Aylık", comment: ""),
                    price: "$4.99 / ay",
                    badge: nil,
                    isSelected: selectedPlan == .monthly
                ) { selectedPlan = .monthly }
            }
            .padding(.horizontal, 24)

            // Butonlar
            VStack(spacing: 8) {
                Button {
                    // TODO: RevenueCat ile değiştir — Purchases.shared.purchase(package:)
                    entitlements.isPro = true
                    onDismiss()
                } label: {
                    Text(NSLocalizedString("Pro'ya Geç", comment: ""))
                }
                .buttonStyle(PinlyPrimaryButtonStyle())

                Button {
                    // TODO: RevenueCat ile değiştir — Purchases.shared.restorePurchases()
                } label: {
                    Text(NSLocalizedString("Satın Alımları Geri Yükle", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button { onDismiss() } label: {
                    Text(NSLocalizedString("Şimdi Değil", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Plan Seçeneği

private enum PlanOption { case yearly, monthly }

private struct PlanOptionButton: View {
    let label: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(PinlyTheme.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PinlyTheme.gold.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    Text(price)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? PinlyTheme.primary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? PinlyTheme.primary.opacity(0.06) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? PinlyTheme.primary : PinlyTheme.fillMuted, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fayda Satırı

private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let badge: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(PinlyTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PinlyTheme.warning.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
