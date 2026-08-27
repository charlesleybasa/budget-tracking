import SwiftUI

struct SuccessView: View {
    var success: SuccessState
    var onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    private let colors: [Color] = [Tokens.accent, Tokens.cream, Tokens.pink, .white]

    var body: some View {
        ZStack {
            Tokens.blue.ignoresSafeArea()
            confetti
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 172, height: 172)
                        .blur(radius: 18)
                    SpriteAnimationView(spec: .celebrate, size: 168)
                }
                Text(success.head)
                    .font(AppFont.outfit(27, weight: .black, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .tracking(-0.8)
                    .padding(.top, 26)
                Text(success.body)
                    .font(AppFont.outfit(14, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 38)
                    .padding(.top, 11)
                Spacer()
                Button("Nice, back to my cards", action: onClose)
                    .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Tokens.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Tokens.accent, in: Capsule())
                    .padding(.horizontal, 26)
                    .padding(.bottom, 44)
                    .buttonStyle(PesolitaPressStyle())
                    .accessibilityIdentifier("close-success")
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.85)) { burst = true }
        }
    }

    private var confetti: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                let angle = Double(index) / 22 * Double.pi * 2
                let distance = CGFloat(150 + (index % 5) * 35)
                RoundedRectangle(cornerRadius: index % 3 == 0 ? 1 : 5)
                    .fill(colors[index % colors.count])
                    .frame(width: index % 2 == 0 ? 8 : 6, height: index % 2 == 0 ? 12 : 8)
                    .rotationEffect(.degrees(burst ? Double(index * 47) : 0))
                    .offset(
                        x: burst ? CGFloat(cos(angle)) * distance : 0,
                        y: burst ? CGFloat(sin(angle)) * distance : 0
                    )
                    .opacity(burst ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
    }
}
