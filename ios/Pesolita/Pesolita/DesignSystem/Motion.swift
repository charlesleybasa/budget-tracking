import SwiftUI

struct PesolitaPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(reduceMotion ? nil : Tokens.easeSpring(0.18), value: configuration.isPressed)
    }
}

struct EnterMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || shown ? 1 : 0)
            .offset(y: reduceMotion || shown ? 0 : 14)
            .onAppear { withAnimation(Tokens.easeOut(0.36)) { shown = true } }
    }
}

extension View {
    func pesolitaEnter() -> some View { modifier(EnterMotion()) }
}

struct AnimatedCurrencyText: View {
    var value: Double
    var font: Font
    var color: Color = Tokens.text
    var prefix = "₱"

    var body: some View {
        Text("\(value < 0 ? "−" : "")\(prefix)\(MoneyFormat.amount(value))")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: value))
    }
}

// MARK: - Elevation

enum ElevationLevel {
    /// Tiles and panels resting on the page.
    case resting
    /// Things that float above scrolling content: the tab bar, overlays.
    case floating
}

/// Depth that works in both appearances.
///
/// A soft black shadow is how light mode says "this floats"; on a near-black page it is
/// invisible, and the first theming pass left every floating surface flat against the page.
/// Dark mode takes its depth from light instead — a hairline brighter along the top edge,
/// where a real object would catch it — with a deeper shadow underneath for separation.
struct PesolitaElevation<S: InsettableShape>: ViewModifier {
    var level: ElevationLevel
    var shape: S
    @Environment(\.colorScheme) private var scheme

    private var radius: CGFloat { level == .floating ? 18 : 10 }
    private var drop: CGFloat { level == .floating ? 8 : 4 }

    func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(level == .floating ? 0.16 : 0.09), .white.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: radius, y: drop)
        } else {
            content
                .overlay(shape.strokeBorder(Tokens.hairline, lineWidth: level == .floating ? 0.5 : 0))
                .shadow(color: .black.opacity(level == .floating ? 0.12 : 0.06), radius: radius, y: drop)
        }
    }
}

extension View {
    func pesolitaElevation<S: InsettableShape>(_ level: ElevationLevel = .resting, in shape: S) -> some View {
        modifier(PesolitaElevation(level: level, shape: shape))
    }
}
