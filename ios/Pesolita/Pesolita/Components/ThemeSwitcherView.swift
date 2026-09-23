import SwiftUI

/// Chooses System, Light or Dark by showing each one.
///
/// Appearance is a visual decision, so the control previews it instead of listing three words
/// in a menu — and the previous menu's yellow label sat on white at about 1.6:1. Each preview
/// is drawn in its own theme's fixed colours on purpose: the Light tile must look light even
/// while the app is dark, or it stops being a preview.
struct ThemeSwitcherView: View {
    let selection: AppTheme
    let onSelect: (AppTheme) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                tile(theme)
            }
        }
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }

    private func tile(_ theme: AppTheme) -> some View {
        let selected = selection == theme
        return Button {
            guard !selected else { return }
            FeedbackCenter.selectionChanged()
            if reduceMotion { onSelect(theme) } else {
                withAnimation(.easeInOut(duration: 0.3)) { onSelect(theme) }
            }
        } label: {
            VStack(spacing: 8) {
                preview(theme)
                    .frame(height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Tokens.accent : Tokens.hairlineStrong, lineWidth: selected ? 2.5 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Tokens.onAccent)
                                .frame(width: 18, height: 18)
                                .background(Tokens.accent, in: Circle())
                                .padding(5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(theme.title)
                    .font(AppFont.outfit(12.5, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Tokens.textPrimary : Tokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func preview(_ theme: AppTheme) -> some View {
        switch theme {
        case .light: MiniScreen(dark: false)
        case .dark: MiniScreen(dark: true)
        case .system:
            // Split down the middle: it follows whatever the phone is set to.
            ZStack {
                MiniScreen(dark: false)
                MiniScreen(dark: true)
                    .mask(
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: geo.size.width * 0.62, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                path.addLine(to: CGPoint(x: geo.size.width * 0.38, y: geo.size.height))
                                path.closeSubpath()
                            }
                        }
                    )
            }
        }
    }
}

/// A thumbnail of the home screen in fixed light or dark colours.
private struct MiniScreen: View {
    let dark: Bool

    private var page: Color { dark ? Color(hex: "#0B0B0D") : Color(hex: "#FFFFFF") }
    private var tile: Color { dark ? Color(hex: "#1B1B20") : Color(hex: "#F5F4F0") }
    private var ink: Color { dark ? Color(hex: "#F5F4F0") : Color(hex: "#0B0B0C") }

    var body: some View {
        ZStack(alignment: .topLeading) {
            page
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(ink.opacity(0.85)).frame(width: 26, height: 4)
                // The wallet card, in the brand's own blue so every preview reads as Pesolita.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#1D6FF2"), Color(hex: "#0B3A8F")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 24)
                    .overlay(alignment: .bottomLeading) {
                        Capsule().fill(.white.opacity(0.9)).frame(width: 18, height: 3).padding(5)
                    }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(tile).frame(height: 12)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#FFCA28")).frame(height: 12)
                }
                Capsule().fill(ink.opacity(0.22)).frame(width: 40, height: 3)
            }
            .padding(8)
        }
    }
}
