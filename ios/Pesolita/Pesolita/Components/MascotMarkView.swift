import SwiftUI

struct MascotMarkView: View {
    var size: CGFloat = 22

    var body: some View {
        if let image = UIImage(named: "brand-mark") {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "ant.fill")
                .font(.system(size: size * 0.72, weight: .bold))
                .foregroundStyle(Tokens.accent)
                .frame(width: size, height: size)
        }
    }
}
