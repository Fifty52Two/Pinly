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

// MARK: - Preference Key (button frame tracking)

private struct ToggleButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Theme Selection View

struct ThemeSelectionView: View {
    var onComplete: () -> Void

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var selectedTheme: AppTheme = .light
    @State private var routeTrim: CGFloat = 0
    @State private var showGuide = false
    @State private var buttonFrame: CGRect = .zero

    private var isLight: Bool { selectedTheme == .light }

    private var bgColor: Color       { isLight ? Color(hex: 0xFBF9F6) : Color(hex: 0x1A1C19) }
    private var titleColor: Color    { isLight ? Color(hex: 0x1b1c1a) : Color(hex: 0xE4E7DD) }
    private var subtitleColor: Color { isLight ? Color(hex: 0x4e453b) : Color(hex: 0xC8CCC0) }
    private var routeColor: Color    { isLight ? Color(hex: 0xC8A97E) : Color(hex: 0xA0A882) }
    private var nodeColor: Color     { isLight ? Color(hex: 0x735a36) : Color(hex: 0xC5C9A4) }
    private var primaryColor: Color  { isLight ? Color(hex: 0x735a36) : Color(hex: 0xC5C9A4) }
    private var buttonBg: Color      { isLight ? Color(hex: 0xC8A97E) : Color(hex: 0xDFE39C) }
    private var buttonText: Color    { isLight ? .white : Color(hex: 0x1A1C19) }
    private var footerColor: Color   { isLight ? Color(hex: 0x1b1c1a).opacity(0.3) : Color(hex: 0xE4E7DD).opacity(0.6) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            GeometryReader { geo in routeBackground(size: geo.size) }
            mainContent
            if showGuide { guideOverlay }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: selectedTheme)
        .onPreferenceChange(ToggleButtonFrameKey.self) { frame in
            buttonFrame = frame
        }
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                routeTrim = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeIn(duration: 0.35)) { showGuide = true }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.top, 64)
                .padding(.horizontal, 24)
            Spacer()
            headlineBlock
            Spacer()
            ctaButton
            signInLink
        }
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 17))
                    .foregroundColor(primaryColor)
                Text("CURATOR ROUTES")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(titleColor)
            }
            Spacer()
            themeToggleButton
        }
    }

    private var themeToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTheme = isLight ? .dark : .light
            }
            if showGuide {
                withAnimation(.easeOut(duration: 0.2)) { showGuide = false }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLight ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 12, weight: .medium))
                Text(isLight ? "Dark" : "Light")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.3)
            }
            .foregroundColor(isLight ? Color(hex: 0x735a36) : Color(hex: 0x1A1C19))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isLight ? Color(hex: 0xC8A97E).opacity(0.18) : Color(hex: 0xDFE39C)))
            .overlay(Capsule().stroke(isLight ? Color(hex: 0xC8A97E).opacity(0.45) : Color(hex: 0xC5C9A4).opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Track this button's frame in global coordinate space
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ToggleButtonFrameKey.self,
                                       value: geo.frame(in: .global))
            }
        )
    }

    private var headlineBlock: some View {
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
    }

    private var ctaButton: some View {
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
    }

    private var signInLink: some View {
        Text("SIGN IN")
            .font(.system(size: 10, weight: .medium))
            .tracking(1)
            .foregroundColor(footerColor)
            .padding(.bottom, 44)
    }

    // MARK: - Guide Overlay

    private var guideOverlay: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // Spotlight: full-screen dark fill with a hole punched at the button
                SpotlightShape(cutout: buttonFrame.insetBy(dx: -10, dy: -8), cornerRadius: 16)
                    .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) { showGuide = false }
                    }

                // Glow ring around the button
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                    .frame(width: buttonFrame.width + 20, height: buttonFrame.height + 16)
                    .position(x: buttonFrame.midX, y: buttonFrame.midY)
                    .allowsHitTesting(false)

                // Callout anchored just below the spotlight hole
                calloutColumn(screenWidth: geo.size.width)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func calloutColumn(screenWidth: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Push down to just below the button
            Color.clear.frame(height: buttonFrame.maxY + 4)

            HStack(spacing: 0) {
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    // Arrow tip
                    GuideArrowTip()
                        .fill(Color.white)
                        .frame(width: 18, height: 11)
                        .padding(.trailing, 28)
                    // Bubble
                    guideBubble
                }
                .padding(.trailing, 16)
            }

            Spacer()
        }
    }

    private var guideBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0xC8A97E))
                Text("Switch your theme")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: 0x1b1c1a))
            }
            Text("Tap this button to toggle between light and dark palettes.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x4e453b))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("TAP ANYWHERE TO CONTINUE")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundColor(Color(hex: 0x735a36).opacity(0.55))
                .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 236)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
        )
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

            // Aquarium node — route start point
            ZStack {
                Circle().fill(bgColor).frame(width: 20, height: 20)
                    .shadow(color: nodeColor.opacity(0.08), radius: 4)
                Circle().fill(nodeColor).frame(width: 7, height: 7)
            }
            .position(x: 50 * sx, y: 650 * sy)

            Text("AQUARIUM")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtitleColor.opacity(0.45))
                .position(x: 50 * sx + 50, y: 650 * sy)

            // Lunch node
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
}

// MARK: - Spotlight Shape (evenOdd hole)

private struct SpotlightShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: cutout,
                            cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

// MARK: - Guide Arrow Tip

struct GuideArrowTip: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
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
