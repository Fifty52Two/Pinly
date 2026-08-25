import SwiftUI

// MARK: - İzin Bekleniyor

struct PermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(PinlyTheme.primary)
            VStack(spacing: 8) {
                Text(NSLocalizedString("Konumuna İhtiyacımız Var", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(NSLocalizedString("Bulunduğun semtteki mekanları göstermek için konum izni gerekiyor.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            VStack(spacing: 12) {
                Button(NSLocalizedString("Konum İzni Ver", comment: ""), action: onAllow)
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .padding(.horizontal, 30)
                Button(NSLocalizedString("Şimdilik Değil", comment: ""), action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - İzin Reddedildi

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                WavePattern(waveLength: 40, amplitude: 5, rowSpacing: 9)
                    .stroke(PinlyTheme.slate.opacity(0.10), lineWidth: 1)
                    .frame(width: 160, height: 100)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 80))
                    .foregroundColor(PinlyTheme.danger)
            }
            VStack(spacing: 8) {
                Text(NSLocalizedString("Konum İzni Gerekli", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(NSLocalizedString("Ayarlar > Pinly > Konum bölümünden izin ver.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(NSLocalizedString("Ayarlara Git", comment: ""))
                    .fontWeight(.semibold)
                    .foregroundColor(PinlyTheme.onAccent)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(PinlyTheme.primary)
                    .cornerRadius(12)
            }
        }
    }
}
