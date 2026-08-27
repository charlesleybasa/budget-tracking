import SwiftUI

struct CardArtView: View {
    var art: CardArt
    var cornerRadius: CGFloat = Tokens.cardR
    var stretchesToFill = false

    @ViewBuilder
    var body: some View {
        if stretchesToFill {
            artwork
        } else {
            artwork.aspectRatio(Tokens.cardW / Tokens.cardH, contentMode: .fit)
        }
    }

    private var artwork: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = size.width / Tokens.cardW
            ZStack {
                Color(hex: art.c1)
                pattern(size: size, scale: scale)
                texture(size: size, scale: scale)
                readabilityScrim
                if art.chip { CardChip(scale: scale, darkText: CardTheme(art: art).useDarkText) }
                LinearGradient(
                    colors: [.clear, .white.opacity(0.20), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: size.width * 0.42)
                .rotationEffect(.degrees(8))
                .offset(x: -size.width * 0.42)
                .blendMode(.screen)
                .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private func pattern(size: CGSize, scale: CGFloat) -> some View {
        switch art.style {
        case .photo:
            if let photo = art.photo {
                ResourceImage(reference: photo.src)
                    .scaleEffect(photo.zoom)
                    .offset(x: size.width * photo.px / 100, y: size.height * photo.py / 100)
                    .blur(radius: photo.blur ? 7 : 0)
            }
        case .blob:
            ZStack {
                Ellipse()
                    .fill(Color(hex: art.c2).opacity(0.94))
                    .frame(width: size.width * 0.80, height: size.height * 1.25)
                    .rotationEffect(.degrees(-18))
                    .offset(x: size.width * 0.30, y: -size.height * 0.13)
                Circle()
                    .fill(.white.opacity(0.50))
                    .frame(width: size.width * 0.54)
                    .blur(radius: 25 * scale)
                    .offset(x: -size.width * 0.34, y: size.height * 0.34)
            }
        case .wave:
            Canvas { context, canvas in
                var first = Path()
                first.move(to: CGPoint(x: -20, y: canvas.height * 0.62))
                first.addCurve(
                    to: CGPoint(x: canvas.width + 20, y: canvas.height * 0.28),
                    control1: CGPoint(x: canvas.width * 0.24, y: canvas.height * 0.05),
                    control2: CGPoint(x: canvas.width * 0.58, y: canvas.height * 0.90)
                )
                first.addLine(to: CGPoint(x: canvas.width + 20, y: canvas.height + 20))
                first.addLine(to: CGPoint(x: -20, y: canvas.height + 20))
                first.closeSubpath()
                context.fill(first, with: .linearGradient(
                    Gradient(colors: [Color(hex: art.c2), Color(hex: art.c2).opacity(0.45)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvas.width, y: canvas.height)
                ))
                var line = Path()
                line.move(to: CGPoint(x: -10, y: canvas.height * 0.63))
                line.addCurve(
                    to: CGPoint(x: canvas.width + 10, y: canvas.height * 0.29),
                    control1: CGPoint(x: canvas.width * 0.25, y: canvas.height * 0.06),
                    control2: CGPoint(x: canvas.width * 0.58, y: canvas.height * 0.90)
                )
                context.stroke(line, with: .color(.white.opacity(0.55)), lineWidth: max(1, scale))
            }
        case .arc:
            Canvas { context, canvas in
                for index in 0..<9 {
                    let inset = CGFloat(index) * 12 * scale
                    let rect = CGRect(
                        x: canvas.width * 0.32 + inset,
                        y: -canvas.height * 0.55 + inset,
                        width: canvas.width * 0.92 - inset * 2,
                        height: canvas.height * 1.55 - inset * 2
                    )
                    context.stroke(Path(ellipseIn: rect), with: .color(Color(hex: art.c2).opacity(0.78 - Double(index) * 0.06)), lineWidth: 4 * scale)
                }
            }
        case .grid:
            Canvas { context, canvas in
                let gap = 18 * scale
                var grid = Path()
                stride(from: -canvas.height, through: canvas.width + canvas.height, by: gap).forEach { value in
                    grid.move(to: CGPoint(x: value, y: 0))
                    grid.addLine(to: CGPoint(x: value - canvas.height, y: canvas.height))
                    grid.move(to: CGPoint(x: value - canvas.height, y: 0))
                    grid.addLine(to: CGPoint(x: value, y: canvas.height))
                }
                context.stroke(grid, with: .color(Color(hex: art.c2).opacity(0.58)), lineWidth: max(1, scale))
            }
        case .confetti:
            ZStack {
                let seeds: [(CGFloat, CGFloat, CGFloat, Double)] = [
                    (0.08, 0.12, 14, 22), (0.24, 0.58, 9, -14), (0.42, 0.20, 12, 40),
                    (0.60, 0.66, 8, 8), (0.74, 0.30, 15, -32), (0.88, 0.74, 10, 18),
                    (0.34, 0.84, 7, 60), (0.52, 0.42, 11, -20), (0.16, 0.40, 8, 34), (0.92, 0.18, 12, 6)
                ]
                ForEach(Array(seeds.enumerated()), id: \.offset) { item in
                    let (index, seed) = item
                    Capsule()
                        .fill(index.isMultiple(of: 3) ? Color.white.opacity(0.80) : Color(hex: art.c2).opacity(0.92))
                        .frame(width: seed.2 * scale, height: seed.2 * 0.42 * scale)
                        .rotationEffect(.degrees(seed.3))
                        .position(x: size.width * seed.0, y: size.height * seed.1)
                }
                RadialGradient(colors: [.white.opacity(0.40), .clear], center: .topLeading, startRadius: 0, endRadius: size.width * 0.72)
            }
        case .planes:
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: art.c1), location: 0),
                        .init(color: Color(hex: art.c1), location: 0.38),
                        .init(color: Color(hex: art.c2), location: 0.39),
                        .init(color: Color(hex: art.c2), location: 0.56),
                        .init(color: Color(hex: art.c1), location: 0.57),
                        .init(color: Color(hex: art.c1), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Rectangle()
                    .fill(Color(hex: art.c2).opacity(0.50))
                    .frame(width: size.width * 0.52, height: size.height * 1.6)
                    .rotationEffect(.degrees(24))
                    .offset(x: size.width * 0.40, y: -size.height * 0.15)
                Canvas { context, canvas in
                    var dots = Path()
                    let gap = 7 * scale
                    for y in stride(from: canvas.height * 0.48, through: canvas.height, by: gap) {
                        for x in stride(from: CGFloat(0), through: canvas.width * 0.58, by: gap) {
                            dots.addEllipse(in: CGRect(x: x, y: y, width: 1.2 * scale, height: 1.2 * scale))
                        }
                    }
                    context.fill(dots, with: .color(.white.opacity(0.30)))
                }
                LinearGradient(colors: [.clear, .white.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .metal:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: art.c1), Color(hex: art.c2), Color(hex: art.c1), Color(hex: art.c2), Color(hex: art.c1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                Canvas { context, canvas in
                    var lines = Path()
                    for x in stride(from: -canvas.height, through: canvas.width, by: 3 * scale) {
                        lines.move(to: CGPoint(x: x, y: canvas.height))
                        lines.addLine(to: CGPoint(x: x + canvas.height * 0.27, y: 0))
                    }
                    context.stroke(lines, with: .color(.white.opacity(0.13)), lineWidth: max(0.7, scale))
                }
                RadialGradient(colors: [.white.opacity(0.50), .clear], center: .center, startRadius: 0, endRadius: size.width * 0.62)
                    .rotationEffect(.degrees(-8))
            }
        case .glyph:
            ZStack(alignment: .trailing) {
                Color(hex: art.c1)
                Text(art.glyph ?? "S")
                    .font(AppFont.outfit(size.height * 1.14, weight: .black, relativeTo: .largeTitle))
                    .foregroundStyle(Color(hex: art.c2).opacity(0.13))
                    .offset(x: size.width * 0.04)
                RadialGradient(colors: [.white.opacity(0.14), .clear], center: .topLeading, startRadius: 0, endRadius: size.width * 0.66)
            }
        case .orbit:
            ZStack {
                Color(hex: art.c1)
                Canvas { context, canvas in
                    let center = CGPoint(x: canvas.width * 0.88, y: canvas.height * 0.78)
                    for radius in stride(from: CGFloat(11) * scale, through: canvas.width * 0.8, by: 24 * scale) {
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(hex: art.c2).opacity(0.55)), lineWidth: 11 * scale)
                    }
                    var stars = Path()
                    for y in stride(from: CGFloat(8), through: canvas.height, by: 13 * scale) {
                        for x in stride(from: CGFloat(8), through: canvas.width, by: 16 * scale) {
                            stars.addEllipse(in: CGRect(x: x, y: y, width: 1.2 * scale, height: 1.2 * scale))
                        }
                    }
                    context.fill(stars, with: .color(.white.opacity(0.50)))
                }
            }
        case .foil:
            ZStack {
                Color(hex: art.c1)
                Ellipse()
                    .stroke(Color(hex: art.c2).opacity(0.95), lineWidth: 3.2 * scale)
                    .frame(width: size.width * 0.96, height: size.height * 1.9)
                    .rotationEffect(.degrees(-16))
                    .offset(x: size.width * 0.37, y: -size.height * 0.18)
                Ellipse()
                    .stroke(Color(hex: art.c2).opacity(0.50), lineWidth: 1.4 * scale)
                    .frame(width: size.width * 0.72, height: size.height * 1.5)
                    .rotationEffect(.degrees(-16))
                    .offset(x: size.width * 0.31, y: -size.height * 0.12)
                LinearGradient(colors: [.clear, .white.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .irid:
            ZStack {
                AngularGradient(colors: [Color(hex: art.c1), Color(hex: art.c2), Color(hex: "#fdf1c9"), Color(hex: art.c1)], center: UnitPoint(x: 0.32, y: 0.20), angle: .degrees(200))
                RadialGradient(colors: [.white.opacity(0.55), .clear], center: .bottomTrailing, startRadius: 0, endRadius: size.width * 0.62)
                Canvas { context, canvas in
                    var dots = Path()
                    for y in stride(from: CGFloat(0), through: canvas.height, by: 6 * scale) {
                        for x in stride(from: CGFloat(0), through: canvas.width, by: 6 * scale) {
                            dots.addEllipse(in: CGRect(x: x, y: y, width: 0.9 * scale, height: 0.9 * scale))
                        }
                    }
                    context.fill(dots, with: .color(.white.opacity(0.45)))
                }
            }
        case .crest:
            ZStack {
                LinearGradient(colors: [Color(hex: art.c1), Color(hex: "#071736")], startPoint: .top, endPoint: .bottomTrailing)
                Rectangle()
                    .fill(Color(hex: art.c2).opacity(0.85))
                    .frame(width: size.width * 0.46, height: size.height * 1.8)
                    .rotationEffect(.degrees(18))
                    .offset(x: -size.width * 0.34, y: -size.height * 0.12)
                Canvas { context, canvas in
                    var verticals = Path()
                    for x in stride(from: CGFloat(0), through: canvas.width, by: 9 * scale) {
                        verticals.move(to: CGPoint(x: x, y: 0)); verticals.addLine(to: CGPoint(x: x, y: canvas.height))
                    }
                    context.stroke(verticals, with: .color(.white.opacity(0.07)), lineWidth: max(0.8, scale))
                    let center = CGPoint(x: canvas.width * 0.74, y: canvas.height * 1.16)
                    for radius in stride(from: CGFloat(13) * scale, through: canvas.width, by: 13 * scale) {
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(0.20)), lineWidth: max(0.8, scale))
                    }
                }
            }
        case .mesh:
            ZStack {
                RadialGradient(colors: [Color(hex: art.c2), .clear], center: .topLeading, startRadius: 1, endRadius: size.width * 0.75)
                RadialGradient(colors: [Color(hex: art.c2).opacity(0.88), .clear], center: .bottomTrailing, startRadius: 1, endRadius: size.width * 0.70)
                RadialGradient(colors: [.white.opacity(0.30), .clear], center: .topTrailing, startRadius: 1, endRadius: size.width * 0.45)
            }
        }
    }

    @ViewBuilder
    private func texture(size: CGSize, scale: CGFloat) -> some View {
        switch art.tex {
        case .grain:
            Canvas { context, canvas in
                let gap = max(3, 3.5 * scale)
                var dots = Path()
                var y: CGFloat = 0
                while y < canvas.height {
                    var x: CGFloat = 0
                    while x < canvas.width {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 0.9 * scale, height: 0.9 * scale))
                        x += gap
                    }
                    y += gap
                }
                context.fill(dots, with: .color(.black.opacity(0.14)))
            }
            .blendMode(.multiply)
        case .dots:
            Canvas { context, canvas in
                var dots = Path()
                for y in stride(from: CGFloat(0), through: canvas.height, by: 13 * scale) {
                    for x in stride(from: CGFloat(0), through: canvas.width, by: 13 * scale) {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 2.8 * scale, height: 2.8 * scale))
                    }
                }
                context.fill(dots, with: .color(.black.opacity(0.18)))
            }
        case .stripes:
            Canvas { context, canvas in
                var lines = Path()
                for x in stride(from: -canvas.height, through: canvas.width, by: 11 * scale) {
                    lines.move(to: CGPoint(x: x, y: canvas.height))
                    lines.addLine(to: CGPoint(x: x + canvas.height * 0.48, y: 0))
                }
                context.stroke(lines, with: .color(.white.opacity(0.15)), lineWidth: 2 * scale)
            }
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var readabilityScrim: some View {
        if let photo = art.photo, photo.scrim != .off {
            let alpha: Double = switch photo.scrim {
            case .off: 0
            case .soft: 0.32
            case .strong: 0.55
            case .veil: 0.50
            }
            let dark = !CardTheme(art: art).useDarkText
            let color = dark ? Color.black : Color.white
            if photo.scrim == .veil {
                color.opacity(alpha)
            } else {
                ZStack {
                    LinearGradient(colors: [color.opacity(alpha), color.opacity(alpha * 0.62), .clear], startPoint: .bottom, endPoint: .top)
                    LinearGradient(colors: [color.opacity(alpha * 0.45), .clear], startPoint: .top, endPoint: .center)
                }
            }
        }
    }
}

private struct CardChip: View {
    var scale: CGFloat
    var darkText: Bool

    var body: some View {
        VStack {
            Spacer().frame(height: 74 * scale)
            HStack(spacing: 10 * scale) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#e8c86a"), Color(hex: "#f6e6ae"), Color(hex: "#c9a03f")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .stroke(Color(hex: "#785a14").opacity(0.55), lineWidth: max(0.8, scale))
                        .padding(8 * scale)
                }
                .frame(width: 40 * scale, height: 30 * scale)

                Image(systemName: "wave.3.right")
                    .font(.system(size: 18 * scale, weight: .medium))
                    .foregroundStyle(darkText ? Tokens.ink.opacity(0.5) : .white.opacity(0.55))
                Spacer()
                HStack(spacing: 5 * scale) {
                    ZStack {
                        Circle().fill(darkText ? Tokens.ink : .white).opacity(0.85).offset(x: -3 * scale)
                        Circle().fill(darkText ? Tokens.ink : .white).opacity(0.42).offset(x: 3 * scale)
                    }
                    .frame(width: 17 * scale, height: 11 * scale)
                    Text("DEBIT")
                        .font(AppFont.outfit(9.5 * scale, weight: .bold, relativeTo: .caption2))
                        .tracking(1.2 * scale)
                }
                .foregroundStyle(darkText ? Tokens.ink : .white)
                .padding(.horizontal, 8 * scale)
                .frame(height: 22 * scale)
                .background((darkText ? Color.white.opacity(0.90) : Tokens.ink.opacity(0.70)), in: Capsule())
            }
            .padding(.horizontal, 19 * scale)
            Spacer()
        }
    }
}

struct CardFaceView: View {
    var card: Card
    var privateMode = false
    var showFreeze = true
    var stretchesToFill = false

    @ViewBuilder
    var body: some View {
        if stretchesToFill { face }
        else { face.aspectRatio(Tokens.cardW / Tokens.cardH, contentMode: .fit) }
    }

    private var face: some View {
        GeometryReader { proxy in
            let scale = stretchesToFill ? min(1, proxy.size.height / Tokens.cardH) : proxy.size.width / Tokens.cardW
            let theme = CardTheme(art: card.art)
            ZStack {
                CardArtView(art: card.art, cornerRadius: Tokens.cardR * scale, stretchesToFill: stretchesToFill)
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5 * scale) {
                            Text(card.kind.rawValue.uppercased())
                                .font(AppFont.outfit(10.5 * scale, weight: .semibold, relativeTo: .caption2))
                                .tracking(1.25 * scale)
                                .foregroundStyle(theme.dimmed)
                            Text(card.nick)
                                .font(AppFont.outfit(14 * scale, weight: .bold, relativeTo: .subheadline))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                        }
                        Spacer()
                        if showFreeze {
                            Capsule()
                                .fill(theme.useDarkText ? Color.white.opacity(0.92) : Tokens.ink)
                                .frame(width: 44 * scale, height: 25 * scale)
                                .overlay(alignment: card.frozen ? .leading : .trailing) {
                                    Circle()
                                        .fill(card.frozen ? (theme.useDarkText ? .white : Tokens.ink) : (theme.useDarkText ? Tokens.ink : Tokens.accent))
                                        .padding(3 * scale)
                                }
                        }
                    }
                    Spacer()
                    Text(MoneyFormat.balance(card.bal, privateMode: privateMode))
                        .font(AppFont.outfit(30 * scale, weight: .bold, relativeTo: .title))
                        .foregroundStyle(theme.foreground)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    HStack {
                        VStack(alignment: .leading, spacing: 4 * scale) {
                            Text("CARD").foregroundStyle(theme.dimmed)
                            Text(card.last4.isEmpty ? (card.kind == .cash ? "Physical pesos" : "No number") : "•••• •••• \(card.last4)")
                                .foregroundStyle(theme.foreground)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4 * scale) {
                            Text("EXP DATE").foregroundStyle(theme.dimmed)
                            Text(card.exp).foregroundStyle(theme.foreground)
                        }
                    }
                    .font(AppFont.outfit(9.5 * scale, weight: .semibold, relativeTo: .caption2))
                }
                .padding(.horizontal, 19 * scale)
                .padding(.vertical, 17 * scale)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.nick), balance \(MoneyFormat.balance(card.bal, privateMode: privateMode))")
    }
}
