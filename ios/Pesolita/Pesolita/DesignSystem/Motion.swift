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
    var color: Color = Tokens.ink
    var prefix = "₱"

    var body: some View {
        Text("\(value < 0 ? "−" : "")\(prefix)\(MoneyFormat.amount(value))")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: value))
    }
}
