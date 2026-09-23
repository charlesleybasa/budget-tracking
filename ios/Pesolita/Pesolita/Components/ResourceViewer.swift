import SwiftUI

struct ResourceViewer: View {
    var title: String
    var subtitle: String
    var reference: String
    var onClose: () -> Void
    var shareItems: [Any]? = nil
    @State private var appeared = false

    private func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // For iPad support
        activityVC.popoverPresentationController?.sourceView = window
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
        activityVC.popoverPresentationController?.permittedArrowDirections = []
        
        topVC.present(activityVC, animated: true)
    }

    var body: some View {
        ZStack {
            Tokens.background.ignoresSafeArea()
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
                            .foregroundStyle(Tokens.text.opacity(0.42))
                    }
                    Spacer()
                    if let shareItems = shareItems {
                        Button(action: { presentShareSheet(items: shareItems) }) {
                            Image(systemName: "square.and.arrow.up")
                                .frame(width: 48, height: 48)
                                .background(Tokens.dark2, in: Circle())
                        }
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }
                }
                .foregroundStyle(Tokens.text)
                .padding(.horizontal, 20)

                ResourceImage(reference: reference, contentMode: .fit)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tokens.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear { withAnimation(Tokens.easeSpring(0.42)) { appeared = true } }
    }
}
