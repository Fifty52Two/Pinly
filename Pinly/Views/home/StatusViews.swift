import SwiftUI

// MARK: - İzin Bekleniyor

struct PermissionView: View {
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
        }
    }
}

// MARK: - İzin Reddedildi

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(PinlyTheme.danger)
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(PinlyTheme.primary)
                    .cornerRadius(12)
            }
        }
    }
}
