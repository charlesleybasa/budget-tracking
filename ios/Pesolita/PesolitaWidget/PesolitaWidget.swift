import CoreText
import SwiftUI
import UIKit
import WidgetKit

struct PesolitaWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetWalletPayload
    let selectedCardID: String

    var card: WidgetCardPayload? {
        payload.cards.first(where: { $0.id == selectedCardID })
            ?? payload.cards.first(where: { $0.id == payload.activeCardID })
            ?? payload.cards.first
    }

    var latestTransaction: WidgetTransactionPayload? {
        guard let card else { return nil }
        return payload.transactions.first(where: { $0.cardID == card.id })
    }
}

struct PesolitaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PesolitaWidgetEntry {
        PesolitaWidgetEntry(date: .now, payload: .placeholder, selectedCardID: "preview-bdo")
    }

    func getSnapshot(in context: Context, completion: @escaping (PesolitaWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PesolitaWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 20, to: .now) ?? .now.addingTimeInterval(1_200)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> PesolitaWidgetEntry {
        let payload = WidgetSharedStore.loadPayload()
        return PesolitaWidgetEntry(
            date: .now,
            payload: payload,
            selectedCardID: WidgetSharedStore.selectedCardID(in: payload)
        )
    }
}

struct PesolitaPocketWidget: Widget {
    let kind = WidgetSharedStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PesolitaWidgetProvider()) { entry in
            PesolitaWidgetView(entry: entry)
        }
        .configurationDisplayName("Pocket at a glance")
        .description("Browse your Pesolita cards, see what is safe today, and jump straight into Spend or Top up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct PesolitaWidgetBundle: WidgetBundle {
    init() { WidgetFont.register() }

    var body: some Widget {
        PesolitaPocketWidget()
    }
}

private struct PesolitaWidgetView: View {
    let entry: PesolitaWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let card = entry.card {
                switch family {
                case .systemSmall: compact(card)
                case .systemMedium: medium(card)
                default: large(card)
                }
            } else {
                emptyWallet
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetPalette.ink }
        .widgetURL(entry.card.map { WidgetRoute.url("card", cardID: $0.id) } ?? WidgetRoute.url("add-card"))
    }

    private func large(_ card: WidgetCardPayload) -> some View {
        VStack(spacing: 10) {
            brandHeader(card: card)

            WidgetCardHero(
                card: card,
                privateMode: entry.payload.privacyEnabled,
                position: cardPosition(card),
                count: entry.payload.cards.count,
                showsNavigation: entry.payload.cards.count > 1
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(320 / 156, contentMode: .fit)
            .invalidatableContent()

            HStack(spacing: 10) {
                statPanel(
                    kicker: "SAFE TODAY",
                    value: money(card.safeToday, privateMode: entry.payload.privacyEnabled),
                    symbol: "checkmark.shield.fill",
                    tint: WidgetPalette.yellow
                )
                recentPanel(card: card)
            }

            actionRow(card: card)
        }
        .padding(14)
    }

    private func medium(_ card: WidgetCardPayload) -> some View {
        HStack(spacing: 11) {
            WidgetCardHero(
                card: card,
                privateMode: entry.payload.privacyEnabled,
                position: cardPosition(card),
                count: entry.payload.cards.count,
                showsNavigation: entry.payload.cards.count > 1,
                condensed: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .invalidatableContent()

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    WidgetBrandMark(size: 22)
                    Text("SAFE TODAY")
                        .font(WidgetFont.outfit(9, weight: .semibold, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.48))
                }
                Text(money(card.safeToday, privateMode: entry.payload.privacyEnabled))
                    .font(WidgetFont.outfit(19, weight: .bold, relativeTo: .title3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer(minLength: 0)
                actionRow(card: card, compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private func compact(_ card: WidgetCardPayload) -> some View {
        ZStack(alignment: .topLeading) {
            WidgetCardBackground(card: card)
            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    WidgetBrandMark(size: 25)
                    Spacer()
                    Image(systemName: card.frozen ? "snowflake" : "checkmark.shield.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(card.frozen ? .cyan : WidgetPalette.yellow)
                }
                Spacer()
                Text(card.name)
                    .font(WidgetFont.outfit(12, weight: .semibold, relativeTo: .caption))
                    .lineLimit(1)
                Text("SAFE TODAY")
                    .font(WidgetFont.outfit(8, weight: .semibold, relativeTo: .caption2))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 6)
                Text(money(card.safeToday, privateMode: entry.payload.privacyEnabled))
                    .font(WidgetFont.outfit(22, weight: .bold, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .padding(13)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), safe today \(money(card.safeToday, privateMode: entry.payload.privacyEnabled))")
    }

    private func brandHeader(card: WidgetCardPayload) -> some View {
        HStack(spacing: 8) {
            WidgetBrandMark(size: 26)
            Text("Pesolita")
                .font(WidgetFont.outfit(14, weight: .bold, relativeTo: .headline))
            Text("POCKET WIDGET")
                .font(WidgetFont.outfit(8.5, weight: .semibold, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Text("\(cardPosition(card)) of \(entry.payload.cards.count)")
                .font(WidgetFont.outfit(10, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.48))
        }
    }

    private func statPanel(kicker: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker)
                    .font(WidgetFont.outfit(8.5, weight: .semibold, relativeTo: .caption2))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.42))
                Text(value)
                    .font(WidgetFont.outfit(15, weight: .bold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 49)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func recentPanel(card: WidgetCardPayload) -> some View {
        let transaction = entry.latestTransaction
        return HStack(spacing: 9) {
            Image(systemName: transaction.map { categorySymbol($0.category) } ?? "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(transaction?.amount ?? 0 >= 0 ? WidgetPalette.green : .white)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.08), in: Circle())
            // Merchant and amount used to share one row inside a half-width panel, so a
            // long name squeezed the amount until it wrapped mid-number ("15,596.0" over
            // "0"). The merchant now rides the label line, leaving the amount a full row
            // of its own — the same kicker-over-value shape as the panel beside it.
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.map { "RECENT · \($0.merchant.uppercased())" } ?? "RECENT")
                    .font(WidgetFont.outfit(8.5, weight: .semibold, relativeTo: .caption2))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let transaction {
                    Text(signedMoney(transaction.amount, privateMode: entry.payload.privacyEnabled))
                        .font(WidgetFont.outfit(15, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(transaction.amount >= 0 ? WidgetPalette.green : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Nothing logged yet")
                        .font(WidgetFont.outfit(11, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 49)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func actionRow(card: WidgetCardPayload, compact: Bool = false) -> some View {
        HStack(spacing: 8) {
            Link(destination: WidgetRoute.url("spend", cardID: card.id)) {
                Group {
                    if compact { Image(systemName: "arrow.up.right") }
                    else { Label("Spend", systemImage: "arrow.up.right") }
                }
                    .frame(maxWidth: .infinity, minHeight: compact ? 38 : 43)
                    .background(WidgetPalette.yellow, in: Capsule())
                    .foregroundStyle(WidgetPalette.ink)
            }
            .accessibilityLabel("Spend from \(card.name)")
            Link(destination: WidgetRoute.url("topup", cardID: card.id)) {
                Group {
                    if compact { Image(systemName: "arrow.down.left") }
                    else { Label("Top up", systemImage: "arrow.down.left") }
                }
                    .frame(maxWidth: .infinity, minHeight: compact ? 38 : 43)
                    .background(.white.opacity(0.10), in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Top up \(card.name)")
        }
        .font(WidgetFont.outfit(compact ? 10.5 : 12, weight: .semibold, relativeTo: .caption))
    }

    private var emptyWallet: some View {
        Link(destination: WidgetRoute.url("add-card")) {
            VStack(spacing: 10) {
                WidgetBrandMark(size: 44)
                Text("Your first pocket is waiting.")
                    .font(WidgetFont.outfit(18, weight: .bold, relativeTo: .headline))
                    .multilineTextAlignment(.center)
                Text("Open Pesolita, add a card, then this widget fills itself in.")
                    .font(WidgetFont.outfit(11, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }
            .padding(18)
        }
    }

    private func cardPosition(_ card: WidgetCardPayload) -> Int {
        (entry.payload.cards.firstIndex(where: { $0.id == card.id }) ?? 0) + 1
    }

    private func money(_ value: Double, privateMode: Bool) -> String {
        guard !privateMode else { return "₱••••" }
        return value.formatted(.currency(code: "PHP").precision(.fractionLength(2)).locale(Locale(identifier: "en_PH")))
    }

    private func signedMoney(_ value: Double, privateMode: Bool) -> String {
        guard !privateMode else { return value >= 0 ? "+₱•••" : "−₱•••" }
        let amount = abs(value).formatted(.currency(code: "PHP").precision(.fractionLength(2)).locale(Locale(identifier: "en_PH")))
        return "\(value >= 0 ? "+" : "−")\(amount)"
    }

    private func categorySymbol(_ category: String) -> String {
        switch category {
        case "Food": "fork.knife"
        case "Transport": "car.fill"
        case "Bills": "doc.text.fill"
        case "Groceries": "basket.fill"
        case "Shopping": "bag.fill"
        case "Load": "antenna.radiowaves.left.and.right"
        case "Health": "cross.case.fill"
        default: "sparkles"
        }
    }
}

private struct WidgetCardHero: View {
    let card: WidgetCardPayload
    let privateMode: Bool
    let position: Int
    let count: Int
    let showsNavigation: Bool
    var condensed = false

    var body: some View {
        ZStack {
            WidgetCardBackground(card: card)
            LinearGradient(colors: [.black.opacity(0.03), .clear, .black.opacity(0.69)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.kind.uppercased())
                            .font(WidgetFont.outfit(condensed ? 7 : 8.5, weight: .semibold, relativeTo: .caption2))
                            .tracking(0.9)
                            .opacity(0.65)
                        Text(card.name)
                            .font(WidgetFont.outfit(condensed ? 11 : 14, weight: .bold, relativeTo: .headline))
                            .lineLimit(1)
                    }
                    Spacer()
                    if card.frozen {
                        Label("Frozen", systemImage: "snowflake")
                            .font(WidgetFont.outfit(8.5, weight: .semibold, relativeTo: .caption2))
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .background(.black.opacity(0.46), in: Capsule())
                    }
                }
                Spacer()
                Text(privateMode ? "₱•••••" : card.balance.formatted(.currency(code: "PHP").precision(.fractionLength(2)).locale(Locale(identifier: "en_PH"))))
                    .font(WidgetFont.outfit(condensed ? 19 : 27, weight: .bold, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                if !condensed {
                    Text(card.last4.isEmpty ? "AVAILABLE BALANCE" : "•••• \(card.last4)")
                        .font(WidgetFont.outfit(8.5, weight: .medium, relativeTo: .caption2))
                        .tracking(0.7)
                        .opacity(0.62)
                }
            }
            .foregroundStyle(.white)
            .padding(condensed ? 10 : 14)

            if showsNavigation {
                HStack {
                    Button(intent: PreviousPocketIntent()) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: condensed ? 10 : 12, weight: .bold))
                            .frame(width: condensed ? 28 : 34, height: condensed ? 28 : 34)
                            .background(.black.opacity(0.52), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous card")
                    Spacer()
                    Button(intent: NextPocketIntent()) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: condensed ? 10 : 12, weight: .bold))
                            .frame(width: condensed ? 28 : 34, height: condensed ? 28 : 34)
                            .background(.black.opacity(0.52), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next card")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, condensed ? 7 : 9)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: condensed ? 16 : 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: condensed ? 16 : 19, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card \(position) of \(count), \(card.name)")
    }
}

private struct WidgetCardBackground: View {
    let card: WidgetCardPayload

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: card.primaryHex), Color(hex: card.secondaryHex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let templatePath = card.templatePath,
                   let image = WidgetResourceLoader.image(templatePath: templatePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Ellipse()
                        .fill(Color(hex: card.secondaryHex).opacity(0.82))
                        .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 1.5)
                        .rotationEffect(.degrees(-18))
                        .offset(x: proxy.size.width * 0.33, y: -proxy.size.height * 0.15)
                    Circle()
                        .fill(.white.opacity(0.20))
                        .frame(width: proxy.size.width * 0.56)
                        .blur(radius: 18)
                        .offset(x: -proxy.size.width * 0.36, y: proxy.size.height * 0.34)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private enum WidgetResourceLoader {
    static func image(templatePath: String) -> UIImage? {
        let nestedURL = Bundle.main.resourceURL?
            .appendingPathComponent("CardTemplates", isDirectory: true)
            .appendingPathComponent(templatePath)
        let flatURL = Bundle.main.url(
            forResource: URL(fileURLWithPath: templatePath).deletingPathExtension().lastPathComponent,
            withExtension: "webp"
        )
        return nestedURL.flatMap { UIImage(contentsOfFile: $0.path) }
            ?? flatURL.flatMap { UIImage(contentsOfFile: $0.path) }
    }
}

private struct WidgetBrandMark: View {
    let size: CGFloat

    var body: some View {
        if let image = UIImage(named: "brand-mark") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: size * 0.58, weight: .bold))
                .foregroundStyle(WidgetPalette.ink)
                .frame(width: size, height: size)
                .background(WidgetPalette.yellow, in: RoundedRectangle(cornerRadius: size * 0.28))
        }
    }
}

private enum WidgetFont {
    static func register() {
        let url = Bundle.main.url(forResource: "Outfit-Variable", withExtension: "ttf")
            ?? Bundle.main.resourceURL?.appendingPathComponent("Fonts/Outfit-Variable.ttf")
        if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }

    static func outfit(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle) -> Font {
        .custom("Outfit", size: size, relativeTo: style).weight(weight)
    }
}

private enum WidgetPalette {
    static let ink = Color(hex: "#0b0b0c")
    static let yellow = Color(hex: "#ffca28")
    static let green = Color(hex: "#0b8f6a")
}

private extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(raw.prefix(6), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}

#Preview(as: .systemLarge) {
    PesolitaPocketWidget()
} timeline: {
    PesolitaWidgetEntry(date: .now, payload: .placeholder, selectedCardID: "preview-bdo")
}

#Preview(as: .systemMedium) {
    PesolitaPocketWidget()
} timeline: {
    PesolitaWidgetEntry(date: .now, payload: .placeholder, selectedCardID: "preview-bdo")
}
