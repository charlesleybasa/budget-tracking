import SwiftUI

/// The native counterpart of the website's card-changing layer. Money choices show the
/// actual pocket, its available balance, and the other side of a move instead of hiding it.
struct MoneyCardPickerSheet: View {
    let title: String
    let cards: [Card]
    let selectedID: String
    var disabledID: String?
    var privateMode = false
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var compactHeight: CGFloat {
        let rows = CGFloat(min(cards.count, 6))
        return min(UIScreen.main.bounds.height * 0.86, max(330, 112 + rows * 74))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Tokens.sand4)
                .frame(width: 38, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            HStack(spacing: 12) {
                Text(title)
                    .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                    .tracking(-0.25)
                    .foregroundStyle(Tokens.ink)
                Spacer()
                Button {
                    FeedbackCenter.closed()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.ink)
                        .frame(width: 44, height: 44)
                        .background(Tokens.sand2, in: Circle())
                }
                .buttonStyle(PesolitaPressStyle())
                .accessibilityLabel("Close")
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.top, 2)
            .padding(.bottom, 2)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        MoneyCardPickerRow(
                            card: card,
                            selected: card.id == selectedID,
                            disabled: card.id == disabledID,
                            privateMode: privateMode,
                            index: index
                        ) {
                            FeedbackCenter.selectionChanged()
                            onSelect(card.id)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .font(AppFont.outfit(15))
        .background(Tokens.paper)
        .preferredColorScheme(.light)
        .presentationBackground(Tokens.paper)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.height(compactHeight), .large])
        .presentationCornerRadius(28)
        .presentationContentInteraction(.scrolls)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct MoneyCardPickerRow: View {
    let card: Card
    let selected: Bool
    let disabled: Bool
    let privateMode: Bool
    let index: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.nick)
                        .font(AppFont.outfit(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    Text(disabled ? "Other side of this move" : "\(card.kind.rawValue) · \(cardMask)")
                        .font(AppFont.outfit(11.5, relativeTo: .caption))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(MoneyFormat.balance(card.bal, privateMode: privateMode))
                    .font(AppFont.outfit(14, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Tokens.ink, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .frame(minHeight: 65)
            .background(selected ? Tokens.sand2 : Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Tokens.ink : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .opacity(dealt || reduceMotion ? 1 : 0)
        .offset(y: dealt || reduceMotion ? 0 : 22)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Tokens.dealCurve(0.42).delay(Double(index) * 0.045)) {
                dealt = true
            }
        }
        .accessibilityIdentifier("money-card-option-\(card.id)")
        .accessibilityLabel("\(card.nick), \(MoneyFormat.balance(card.bal, privateMode: privateMode))")
        .accessibilityValue(selected ? "Selected" : disabled ? "Already the other side of this move" : cardMask)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            CardArtView(art: card.art, cornerRadius: 9)
                .frame(width: 74, height: 47)
            Text(String(card.nick.prefix(1)).uppercased())
                .font(AppFont.outfit(15, weight: .black, relativeTo: .caption))
                .foregroundStyle(CardTheme(art: card.art).foreground.opacity(0.90))
                .padding(.leading, 8)
                .padding(.bottom, 5)
        }
        .frame(width: 74, height: 47)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityHidden(true)
    }

    private var cardMask: String {
        if !card.last4.isEmpty { return "•••• •••• \(card.last4)" }
        return card.kind == .cash ? "Physical pesos" : "No number"
    }
}
