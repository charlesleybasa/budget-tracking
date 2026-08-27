import SwiftUI
import UniformTypeIdentifiers

struct ScreenTitle: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(AppFont.outfit(10.5, weight: .semibold, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(dark ? Color.white.opacity(0.42) : Tokens.muted2)
            }
            Text(title)
                .font(AppFont.outfit(30, weight: .black, relativeTo: .largeTitle))
                .foregroundStyle(dark ? .white : Tokens.ink)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.outfit(13.5, relativeTo: .subheadline))
                    .foregroundStyle(dark ? Color.white.opacity(0.48) : Tokens.muted1)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TransactionRowView: View {
    var transaction: Transaction
    var card: Card?
    var showCard = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(transaction.amount > 0 ? Tokens.greenPale : Color(hex: "#fff0ef"))
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(transaction.amount > 0 ? Tokens.green : Color(hex: transaction.cat.colorHex))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.merchant)
                        .font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline))
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(transaction.cat.rawValue)
                        if showCard, let card {
                            Text("·")
                            Text(card.nick)
                        }
                        if transaction.receipt != nil {
                            Image(systemName: "paperclip")
                        }
                    }
                    .font(AppFont.outfit(11.5, relativeTo: .caption))
                    .foregroundStyle(Tokens.muted2)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("\(transaction.amount > 0 ? "+" : "−")₱\(MoneyFormat.amount(transaction.amount))")
                    .font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(transaction.amount > 0 ? Tokens.green : Tokens.ink)
                    .contentTransition(.numericText())
            }
            .contentShape(Rectangle())
            .padding(.vertical, 11)
        }
        .buttonStyle(PesolitaPressStyle())
        .disabled(action == nil)
    }

    private var icon: String {
        if transaction.amount > 0 { return "arrow.down.left" }
        return switch transaction.cat {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .bills: "doc.text.fill"
        case .groceries: "basket.fill"
        case .shopping: "bag.fill"
        case .load: "antenna.radiowaves.left.and.right"
        case .health: "cross.case.fill"
        case .fun: "sparkles"
        }
    }
}

struct CardPickerLabel: View {
    var caption: String
    var card: Card?
    var dark = false

    var body: some View {
        HStack(spacing: 12) {
            if let card {
                CardArtView(art: card.art, cornerRadius: 8)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(caption.uppercased())
                        .font(AppFont.outfit(9.5, weight: .semibold, relativeTo: .caption2))
                        .tracking(1)
                        .foregroundStyle(dark ? Color.white.opacity(0.42) : Tokens.muted2)
                    Text(card.nick)
                        .font(AppFont.outfit(14.5, weight: .bold, relativeTo: .subheadline))
                        .foregroundStyle(dark ? .white : Tokens.ink)
                    Text("₱\(MoneyFormat.amount(card.bal)) available")
                        .font(AppFont.outfit(11.5, relativeTo: .caption))
                        .foregroundStyle(dark ? Color.white.opacity(0.46) : Tokens.muted1)
                }
            } else {
                Text("Choose a card")
                    .font(AppFont.outfit(14, weight: .bold, relativeTo: .subheadline))
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(dark ? Color.white.opacity(0.42) : Tokens.muted2)
        }
        .padding(13)
        .background(dark ? Tokens.dark2 : Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProgressRingView: View {
    var progress: Double
    var label: String
    var tint: Color = Tokens.green

    var body: some View {
        ZStack {
            Circle().stroke(Tokens.sand3, lineWidth: 9)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Tokens.easeSpring(0.72), value: progress)
            Text(label)
                .font(AppFont.outfit(15, weight: .black, relativeTo: .subheadline))
                .foregroundStyle(Tokens.ink)
                .minimumScaleFactor(0.6)
        }
    }
}

struct EmptyMascotView: View {
    var spec: SpriteSpec = .idleSteady
    var title: String
    var bodyText: String
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 5 : 8) {
            SpriteAnimationView(spec: spec, size: compact ? 86 : 112)
                .frame(width: compact ? 86 : 112, height: compact ? 86 : 112)
            Text(title)
                .font(AppFont.outfit(compact ? 17 : 20, weight: .black, relativeTo: .title3))
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(bodyText)
                .font(AppFont.outfit(13, relativeTo: .subheadline))
                .foregroundStyle(Tokens.muted2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct PesolitaCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PhotoResourceView: View {
    var reference: String

    var body: some View {
        ResourceImage(reference: reference, contentMode: .fit)
            .background(Tokens.sand1)
    }
}
