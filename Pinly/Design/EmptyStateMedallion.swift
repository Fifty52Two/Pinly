import SwiftUI

// MARK: - EmptyStateMedallion
//
// Boş durum ikonu için ortak "madalyon" görünümü — dairesel seigaiha dokusu +
// merkezde renkli rozet ikonu. Claude Design'da hazırlanan "Pinly Seigaiha
// Uygulama" mockup'ından BİREBİR: gerçek seigaiha PNG doku asseti
// (Assets.xcassets/SeigaihaPattern, açık/koyu moda göre otomatik değişir).
struct EmptyStateMedallion: View {
    let icon: String
    var badgeColor: Color = PinlyTheme.accent

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(PinlyTheme.ground)
                .frame(width: 132, height: 132)
            Image(PinlyTheme.seigaihaLinesOnPaper(colorScheme))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: 132, height: 132)
                .clipShape(Circle())
            Circle()
                .fill(badgeColor)
                .frame(width: 56, height: 56)
                .shadow(color: badgeColor.opacity(0.35), radius: 10, y: 4)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(PinlyTheme.onAccent)
        }
        .accessibilityHidden(true)
    }
}
