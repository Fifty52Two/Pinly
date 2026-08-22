import SwiftUI

// MARK: - Coming Soon Badge Component

struct ComingSoonBadge: View {
    var title: String = NSLocalizedString("ÇOK YAKINDA", comment: "")
    var icon: String = "sparkles"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [PinlyTheme.gold, PinlyTheme.accent],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .shadow(color: PinlyTheme.gold.opacity(0.3), radius: 3, x: 0, y: 1)
    }
}

// MARK: - View Modifier Extension

struct ComingSoonModifier: ViewModifier {
    let isLocked: Bool
    var message: String = NSLocalizedString("ÇOK YAKINDA", comment: "")
    var icon: String = "sparkles"
    var showBlur: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    ComingSoonBadge(title: message, icon: icon)
                        .padding(6)
                }
            }
            .opacity(isLocked ? 0.75 : 1.0)
    }
}

extension View {
    func comingSoon(isLocked: Bool = true, message: String = NSLocalizedString("ÇOK YAKINDA", comment: ""), icon: String = "sparkles") -> some View {
        modifier(ComingSoonModifier(isLocked: isLocked, message: message, icon: icon))
    }
}
