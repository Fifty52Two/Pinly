import SwiftUI

// MARK: - Onboarding (ilk açılış tanıtım akışı)

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "mappin.and.ellipse",
            accent: PinlyTheme.primary,
            title: NSLocalizedString("Mekanlarını Kaydet", comment: ""),
            subtitle: NSLocalizedString("Gittiğin ya da gitmek istediğin her yeri kategorilerle sakla. Swarm geçmişini tek dokunuşla içeri aktar.", comment: "")
        ),
        OnboardingPage(
            icon: "figure.walk.motion",
            accent: PinlyTheme.slate,
            title: NSLocalizedString("Rotanı Planla, Yürü", comment: ""),
            subtitle: NSLocalizedString("Mekanlarından yürüyüş rotası oluştur. Adım adım navigasyon kilit ekranında seni takip eder.", comment: "")
        ),
        OnboardingPage(
            icon: "trophy.fill",
            accent: PinlyTheme.accent,
            title: NSLocalizedString("Rozet Kazan, Paylaş", comment: ""),
            subtitle: NSLocalizedString("22 rozet, haftalık raporlar ve arkadaşlarınla QR kod ile rota paylaşımı seni bekliyor.", comment: "")
        ),
    ]

    var body: some View {
        ZStack {
            PinlyTheme.groundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button(NSLocalizedString("Atla", comment: "")) {
                            onFinish()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                        OnboardingPageView(page: p)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Sayfa göstergesi
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? PinlyTheme.primary : Color.primary.opacity(0.15))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 28)

                Button {
                    if page < pages.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            page += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pages.count - 1
                         ? NSLocalizedString("Devam Et", comment: "")
                         : NSLocalizedString("Başla", comment: ""))
                }
                .buttonStyle(PinlyPrimaryButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
    }
}

// MARK: - Sayfa Modeli

private struct OnboardingPage {
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
}

// MARK: - Tek Sayfa

private struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Arka halkalar — kâğıt üzerinde yumuşak, düşük kontrast
                Circle()
                    .stroke(page.accent.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(page.accent.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 164, height: 164)
                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 128, height: 128)
                Image(systemName: page.icon)
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(page.accent)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            .offset(y: appeared ? 0 : 16)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
