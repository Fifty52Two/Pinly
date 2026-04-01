import SwiftUI

struct PaywallView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Başlık
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .padding(.top, 32)

                Text("Mekan Limitine Ulaştın")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Ücretsiz planda en fazla \(FreemiumManager.freeLimit) mekan kaydedebilirsin.\nSınırsız mekan için Pro'ya geç.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Fayda listesi
            VStack(alignment: .leading, spacing: 14) {
                ProFeatureRow(icon: "mappin.and.ellipse", color: .blue,
                              title: "Sınırsız Mekan",
                              subtitle: "İstediğin kadar mekan kaydet",
                              badge: nil)
                ProFeatureRow(icon: "map.fill", color: .green,
                              title: "Sınırsız Rota",
                              subtitle: "Dilediğin kadar rota oluştur",
                              badge: nil)
                ProFeatureRow(icon: "wifi.slash", color: .orange,
                              title: "Çevrimdışı Harita",
                              subtitle: "İnternetsiz de çalışır",
                              badge: "Yakında")
                ProFeatureRow(icon: "person.2.fill", color: .purple,
                              title: "Grup Rotaları",
                              subtitle: "Arkadaşlarınla birlikte planla",
                              badge: "Yakında")
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 8)

            Spacer()

            // Butonlar
            VStack(spacing: 12) {
                Button {
                    FreemiumManager.isPro = true
                    onDismiss()
                } label: {
                    Text("Pro'ya Geç")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Şimdi Değil")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
                    .font(.system(size: 18))
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
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
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
