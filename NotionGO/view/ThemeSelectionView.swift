import SwiftUI

// MARK: - App Theme

enum AppTheme: String {
    case light = "light"
    case dark  = "dark"

    var displayName: String {
        switch self {
        case .light: return "Ivory & Gilded"
        case .dark:  return "Obsidian & Muted Gilt"
        }
    }
}

// MARK: - Theme Selection View

struct ThemeSelectionView: View {
    var onComplete: () -> Void

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var selectedTheme: AppTheme = .light
    @State private var routeTrim: CGFloat = 0

    private var isLight: Bool { selectedTheme == .light }

    // All colors are theme-reactive — layout never changes
    private var bgColor: Color       { isLight ? Color(hex: 0xFBF9F6) : Color(hex: 0x1A1C19) }
    private var titleColor: Color    { isLight ? Color(hex: 0x1b1c1a) : Color(hex: 0xE4E7DD) }
    private var subtitleColor: Color { isLight ? Color(hex: 0x4e453b) : Color(hex: 0xC8CCC0) }
    private var routeColor: Color    { isLight ? Color(hex: 0xC8A97E) : Color(hex: 0xA0A882) }
    private var nodeColor: Color     { isLight ? Color(hex: 0x735a36) : Color(hex: 0xC5C9A4) }
    private var primaryColor: Color  { isLight ? Color(hex: 0x735a36) : Color(hex: 0xC5C9A4) }
    private var buttonBg: Color      { isLight ? Color(hex: 0xC8A97E) : Color(hex: 0xDFE39C) }
    private var buttonText: Color    { isLight ? .white : Color(hex: 0x1A1C19) }
    private var footerColor: Color   { (isLight ? Color(hex: 0x1b1c1a) : Color(hex: 0xE4E7DD)).opacity(isLight ? 0.3 : 0.6) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            GeometryReader { geo in
                routeBackground(size: geo.size)
            }

            VStack(spacing: 0) {
                // Logo
                HStack(spacing: 7) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 17))
                        .foregroundColor(primaryColor)
                    Text("CURATOR ROUTES")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(titleColor)
                }
                .padding(.top, 64)

                Spacer()

                // Headline & subtitle
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your day,\nintelligently\nmapped")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(titleColor)
                        .tracking(-0.5)
                        .lineSpacing(2)

                    Text("From your first coffee to your last stop — seamlessly.")
                        .font(.system(size: 15))
                        .foregroundColor(subtitleColor)
                        .lineSpacing(4)
                        .frame(maxWidth: 260, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                Spacer()

                // Theme picker
                VStack(spacing: 10) {
                    Text("CHOOSE YOUR THEME")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .foregroundColor(subtitleColor.opacity(0.5))

                    HStack(spacing: 12) {
                        themeCard(.light)
                        themeCard(.dark)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // CTA Button — identical size & text for both themes
                Button {
                    storedTheme = selectedTheme.rawValue
                    onComplete()
                } label: {
                    Text("Start Exploring")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(buttonBg)
                        .clipShape(Capsule())
                        .shadow(color: buttonBg.opacity(0.25), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Sign in link
                Text("SIGN IN")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(footerColor)
                    .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: selectedTheme)
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                routeTrim = 1
            }
        }
    }

    // MARK: - Route Background

    @ViewBuilder
    private func routeBackground(size: CGSize) -> some View {
        let sx = size.width  / 400
        let sy = size.height / 800

        ZStack {
            OnboardingRoutePath()
                .stroke(routeColor.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: size.width, height: size.height)

            OnboardingRoutePath()
                .trim(from: 0, to: routeTrim)
                .stroke(routeColor.opacity(0.42),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: size.width, height: size.height)

            // Right-side node — clear of the left-aligned headline
            ZStack {
                Circle().fill(bgColor).frame(width: 20, height: 20)
                    .shadow(color: nodeColor.opacity(0.08), radius: 4)
                Circle().fill(nodeColor).frame(width: 7, height: 7)
            }
            .position(x: 350 * sx, y: 500 * sy)
            Text("LUNCH")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtitleColor.opacity(0.45))
                .position(x: 350 * sx - 40, y: 500 * sy)

            // Top end node — sits just below the logo
            Circle()
                .fill(nodeColor.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(Circle().fill(nodeColor).frame(width: 10, height: 10))
                .position(x: 200 * sx, y: 100 * sy)
            Text("COFFEE")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtitleColor.opacity(0.45))
                .position(x: 200 * sx + 46, y: 100 * sy)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Theme Card

    @ViewBuilder
    private func themeCard(_ theme: AppTheme) -> some View {
        let isSelected    = selectedTheme == theme
        let cardIsLight   = theme == .light
        let cardBg: Color = cardIsLight ? Color(hex: 0xFBF9F6) : Color(hex: 0x1A1C19)
        let accent: Color = cardIsLight ? Color(hex: 0xC8A97E) : Color(hex: 0xC5C9A4)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTheme = theme
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cardBg)
                        .frame(height: 70)
                        .overlay {
                            GeometryReader { c in
                                ZStack {
                                    Path { p in
                                        p.move(to: CGPoint(x: 12, y: 52))
                                        p.addCurve(
                                            to: CGPoint(x: c.size.width * 0.65, y: 20),
                                            control1: CGPoint(x: 36, y: 42),
                                            control2: CGPoint(x: c.size.width * 0.4, y: 26)
                                        )
                                        p.addLine(to: CGPoint(x: c.size.width - 8, y: 10))
                                    }
                                    .stroke(accent.opacity(0.5),
                                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                                    VStack {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(accent)
                                            .frame(width: 68, height: 10)
                                            .padding(.bottom, 9)
                                    }
                                }
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? accent : Color.gray.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1)
                        )

                    if isSelected {
                        Circle()
                            .fill(accent)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(cardIsLight ? .white : Color(hex: 0x1A1C19))
                            )
                            .padding(5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(theme.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .tracking(0.3)
                    .foregroundColor(isSelected ? primaryColor : subtitleColor.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Route Path Shape

struct OnboardingRoutePath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 400
        let sy = rect.height / 800

        return Path { p in
            p.move(to: CGPoint(x: 50 * sx,  y: 650 * sy))
            p.addCurve(to: CGPoint(x: 350 * sx, y: 500 * sy),
                       control1: CGPoint(x: 120 * sx, y: 600 * sy),
                       control2: CGPoint(x: 280 * sx, y: 650 * sy))
            p.addCurve(to: CGPoint(x: 100 * sx, y: 350 * sy),
                       control1: CGPoint(x: 400 * sx, y: 400 * sy),
                       control2: CGPoint(x: 300 * sx, y: 300 * sy))
            p.addCurve(to: CGPoint(x: 200 * sx, y: 100 * sy),
                       control1: CGPoint(x: 0,        y: 400 * sy),
                       control2: CGPoint(x: 100 * sx, y: 200 * sy))
        }
    }
}

// MARK: - Preview

#Preview {
    ThemeSelectionView(onComplete: {})
}
