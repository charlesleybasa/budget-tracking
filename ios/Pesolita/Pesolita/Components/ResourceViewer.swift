import SwiftUI

struct ResourceViewer: View {
    var title: String
    var subtitle: String
    var reference: String
    var onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 48, height: 48)
                            .background(Tokens.dark2, in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(title)
                            .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(AppFont.outfit(10.5, relativeTo: .caption2))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

                ResourceImage(reference: reference, contentMode: .fit)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(Tokens.easeSpring(0.42)) { appeared = true } }
    }
}
