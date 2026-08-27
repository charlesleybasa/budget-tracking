import SwiftUI

struct TransferView: View {
    @Bindable var store: WalletStore
    @State private var picking: TransferCardPicker?

    private var canMove: Bool {
        guard let from = store.transferFromCard, let to = store.transferToCard else { return false }
        return from.id != to.id && store.typedAmount > 0 && store.typedAmount <= from.bal
    }

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    routePicker
                    amount
                    quickAmounts
                    MoneyKeypad(onKey: store.pressKey, dark: true)
                    moveButton
                    Text("Nothing leaves your phone. This only moves the balance between your own Pesolita cards.")
                        .font(AppFont.outfit(11.5, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.34))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 26)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .blur(radius: picking == nil ? 0 : 3)
        .preferredColorScheme(.dark)
        .sheet(item: $picking) { target in
            MoneyCardPickerSheet(
                title: target == .from ? "Move money from" : "Move money to",
                cards: store.snapshot.cards,
                selectedID: target == .from ? store.transferFromID : store.transferToID,
                disabledID: target == .from ? store.transferToID : store.transferFromID,
                privateMode: store.snapshot.privacy
            ) { id in
                if target == .from { store.transferFromID = id }
                else { store.transferToID = id }
                picking = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Button { store.popRoute() } label: {
                Image(systemName: "xmark")
                    .frame(width: 48, height: 48)
                    .background(Tokens.dark2, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Move money")
                    .font(AppFont.outfit(20, weight: .black, relativeTo: .title3))
                Text("Pick where from and where to")
                    .font(AppFont.outfit(10.5, relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
        .foregroundStyle(.white)
        .padding(.top, 6)
    }

    private var routePicker: some View {
        VStack(spacing: 8) {
            cardPicker(caption: "From", selected: store.transferFromCard, target: .from)
            Button { store.swapTransferCards() } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 42, height: 42)
                    .background(Tokens.accent, in: Circle())
                    .overlay(Circle().stroke(Tokens.ink, lineWidth: 5))
            }
            .buttonStyle(PesolitaPressStyle())
            .padding(.vertical, -15)
            .zIndex(2)
            cardPicker(caption: "To", selected: store.transferToCard, target: .to)
        }
        .padding(8)
        .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(.white.opacity(0.06)))
    }

    private func cardPicker(caption: String, selected: Card?, target: TransferCardPicker) -> some View {
        Button {
            FeedbackCenter.opened()
            picking = target
        } label: {
            CardPickerLabel(caption: caption, card: selected, dark: true)
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityIdentifier(target == .from ? "money-card-picker-source" : "money-card-picker-destination")
        .accessibilityLabel("Move \(caption.lowercased()) \(selected?.nick ?? "unselected card"). Change card")
    }

    private var amount: some View {
        VStack(spacing: 5) {
            Text("AMOUNT TO MOVE")
                .font(AppFont.outfit(10, weight: .semibold, relativeTo: .caption2))
                .tracking(1.25)
                .foregroundStyle(.white.opacity(0.38))
            Text("₱\(store.amountDraft.isEmpty ? "0.00" : MoneyFormat.grouped(draft: store.amountDraft))")
                .font(AppFont.outfit(48, weight: .black, relativeTo: .largeTitle))
                .foregroundStyle(store.transferFromCard.map { store.typedAmount > $0.bal } == true ? Tokens.red : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
            if let from = store.transferFromCard, store.typedAmount > from.bal {
                Text("\(from.nick) is short by ₱\(MoneyFormat.amount(store.typedAmount - from.bal))")
                    .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(Tokens.red)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(minHeight: 100)
        .animation(Tokens.easeSpring(0.25), value: canMove)
    }

    private var quickAmounts: some View {
        HStack(spacing: 8) {
            ForEach([100.0, 500.0, 1000.0], id: \.self) { value in
                Button("+₱\(Int(value))") {
                    store.amountDraft = String(format: "%.2f", value)
                    FeedbackCenter.selectionChanged()
                }
                .font(AppFont.outfit(11.5, weight: .bold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Tokens.dark2, in: Capsule())
                .buttonStyle(PesolitaPressStyle())
            }
            if let source = store.transferFromCard {
                Button("All") {
                    store.amountDraft = String(format: "%.2f", source.bal)
                    FeedbackCenter.selectionChanged()
                }
                .font(AppFont.outfit(11.5, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Tokens.accent)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Tokens.dark2, in: Capsule())
                .buttonStyle(PesolitaPressStyle())
            }
        }
    }

    private var moveButton: some View {
        Button { store.performTransfer() } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                Text("Move it")
            }
            .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
            .foregroundStyle(canMove ? Tokens.ink : .white.opacity(0.34))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(canMove ? Tokens.accent : Tokens.dark2, in: Capsule())
        }
        .buttonStyle(PesolitaPressStyle())
        .disabled(!canMove)
    }
}

private enum TransferCardPicker: String, Identifiable {
    case from
    case to

    var id: String { rawValue }
}
