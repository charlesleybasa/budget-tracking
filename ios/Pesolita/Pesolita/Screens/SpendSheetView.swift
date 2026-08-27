import PhotosUI
import SwiftUI

struct SpendSheetView: View {
    @Bindable var store: WalletStore
    @State private var photoItem: PhotosPickerItem?
    @State private var picking: TransactionCardPicker?

    private var mode: TransactionSheetKind { store.sheet ?? .withdraw }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Tokens.sand4).frame(width: 40, height: 5).padding(.top, 10)
            HStack {
                Text(title)
                    .font(AppFont.outfit(23, weight: .black, relativeTo: .title2))
                Spacer()
                Button { store.dismissSheet() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(Tokens.sand2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Picker("Transaction type", selection: Binding(
                get: { mode },
                set: { newMode in store.changeSheetMode(newMode) }
            )) {
                Text("Spend").tag(TransactionSheetKind.withdraw)
                Text("Top up").tag(TransactionSheetKind.deposit)
                Text("Move").tag(TransactionSheetKind.move)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 14) {
                    amountHeader
                    if store.spendOverage > 0 { overageNotice }
                    if mode == .move { moveCardPicker }
                    else { sourcePicker }
                    if mode != .move {
                        categoryPicker
                        noteField
                        receiptPicker
                    }
                    MoneyKeypad(onKey: store.pressKey)
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .font(AppFont.outfit(15))
        .background(.white)
        .blur(radius: picking == nil ? 0 : 3)
        .preferredColorScheme(.light)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .sheet(item: $picking) { target in
            MoneyCardPickerSheet(
                title: pickerTitle(for: target),
                cards: store.snapshot.cards,
                selectedID: target == .source ? store.sheetCardID : store.moveToCardID,
                disabledID: mode == .move
                    ? (target == .source ? store.moveToCardID : store.sheetCardID)
                    : nil,
                privateMode: store.snapshot.privacy
            ) { id in
                if target == .source { store.sheetCardID = id }
                else { store.moveToCardID = id }
                picking = nil
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await store.attachReceipt(data)
                } else {
                    store.showToast("Could not attach that photo.")
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .withdraw: "Log a spend"
        case .deposit: "Top up a card"
        case .move: "Move money"
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mode == .withdraw ? "−₱" : mode == .deposit ? "+₱" : "₱")
                    .foregroundStyle(amountAccent)
                Text(store.amountDraft.isEmpty ? "0.00" : MoneyFormat.grouped(draft: store.amountDraft))
                    .foregroundStyle(store.spendOverage > 0 ? Tokens.redDeep : Tokens.ink)
            }
            .font(AppFont.outfit(46, weight: .black, relativeTo: .largeTitle))
            .minimumScaleFactor(0.64)
            .lineLimit(1)
            Text(amountSubtitle)
                .font(AppFont.outfit(12.5, relativeTo: .caption))
                .foregroundStyle(Tokens.muted2)
                .multilineTextAlignment(.center)
        }
    }

    private var overageNotice: some View {
        HStack(spacing: 10) {
            SpriteAnimationView(spec: .noNoNo, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("That is more than \(store.sheetCard?.nick ?? "this card") has")
                    .font(AppFont.outfit(13.5, weight: .bold, relativeTo: .subheadline))
                Text("Short by ₱\(MoneyFormat.amount(store.spendOverage)).")
                    .font(AppFont.outfit(12, relativeTo: .caption))
                    .foregroundStyle(Tokens.redDeep)
            }
            Spacer()
            Button("Spend all") { store.spendAll() }
                .font(AppFont.outfit(11, weight: .bold, relativeTo: .caption))
        }
        .padding(12)
        .background(Color(hex: "#fff0ef"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourcePicker: some View {
        Button {
            FeedbackCenter.opened()
            picking = .source
        } label: {
            HStack(spacing: 11) {
                if let card = store.sheetCard {
                    CardArtView(art: card.art, cornerRadius: 7)
                        .frame(width: 44, height: 29)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode == .deposit ? "INTO" : "OUT OF")
                            .font(AppFont.outfit(10, weight: .medium, relativeTo: .caption2))
                            .tracking(1)
                            .foregroundStyle(Tokens.muted3)
                        Text(card.nick)
                            .font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                    }
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("Change")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Tokens.blue)
            }
            .foregroundStyle(Tokens.ink)
            .padding(.horizontal, 13)
            .frame(minHeight: 49)
            .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityIdentifier("money-card-picker-source")
        .accessibilityLabel("\(mode == .deposit ? "Top up into" : "Spend out of") \(store.sheetCard?.nick ?? "unselected card"). Change card")
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(CategoryName.allCases) { category in
                    Button {
                        store.categoryDraft = category
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: category.colorHex)).frame(width: 7, height: 7)
                            Text(category.rawValue)
                        }
                        .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(store.categoryDraft == category ? .white : Tokens.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(store.categoryDraft == category ? Tokens.ink : Tokens.sand1, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var moveCardPicker: some View {
        HStack(spacing: 7) {
            moveEndpoint(label: "From", card: store.sheetCard, target: .source)

            Button {
                let oldSource = store.sheetCardID
                store.sheetCardID = store.moveToCardID
                store.moveToCardID = oldSource
                FeedbackCenter.snap()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 36, height: 36)
                    .background(Tokens.accent, in: Circle())
            }
            .buttonStyle(PesolitaPressStyle())
            .accessibilityLabel("Swap from and to cards")

            moveEndpoint(label: "To", card: store.moveToCard, target: .destination)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cards for this move")
    }

    private func moveEndpoint(label: String, card: Card?, target: TransactionCardPicker) -> some View {
        Button {
            FeedbackCenter.opened()
            picking = target
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(AppFont.outfit(10, weight: .bold, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Tokens.blue)
                HStack(spacing: 8) {
                    if let card {
                        CardArtView(art: card.art, cornerRadius: 7)
                            .frame(width: 44, height: 29)
                    } else {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Tokens.dark2)
                            .frame(width: 44, height: 29)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card?.nick ?? "Pick a card")
                            .font(AppFont.outfit(12, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                        Text(card.map { "₱\(MoneyFormat.amount($0.bal)) available" } ?? "Destination")
                            .font(AppFont.outfit(9.5, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(Tokens.muted2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityIdentifier(target == .source ? "money-card-picker-source" : "money-card-picker-destination")
        .accessibilityLabel("Move \(label.lowercased()) \(card?.nick ?? "unselected card"). Change card")
    }

    private var amountSubtitle: String {
        switch mode {
        case .withdraw: "Cash, card, tap — you type it, we remember it"
        case .deposit: "Cash in, salary, refund — anything coming in"
        case .move: "Same money, different pocket. Your total will not budge."
        }
    }

    private var amountAccent: Color {
        if store.spendOverage > 0 { return Tokens.redDeep }
        return switch mode {
        case .withdraw: Tokens.red
        case .deposit: Tokens.green
        case .move: Tokens.blue
        }
    }

    private func pickerTitle(for target: TransactionCardPicker) -> String {
        if target == .destination { return "Move it into" }
        return switch mode {
        case .withdraw: "Spend out of"
        case .deposit: "Top up into"
        case .move: "Move it out of"
        }
    }

    private var noteField: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft").foregroundStyle(Tokens.muted3)
                TextField("What was it? (I'll guess the category)", text: $store.noteDraft)
                    .font(AppFont.outfit(13, relativeTo: .subheadline))
                    .textInputAutocapitalization(.sentences)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let guess = store.guessCategory(), guess != store.categoryDraft {
                Button {
                    store.categoryDraft = guess
                } label: {
                    Label("Looks like \(guess.rawValue) — tap to use it", systemImage: "checkmark.circle.fill")
                        .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(Tokens.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var receiptPicker: some View {
        let attached = store.receiptDraft != nil
        return PhotosPicker(selection: $photoItem, matching: .images) {
            Label(attached ? "Replace receipt" : "Attach receipt", systemImage: "camera")
                .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(attached ? Color.white : Tokens.muted1)
                .padding(.horizontal, 13)
                .frame(minHeight: 42)
                .background(attached ? Tokens.ink : Tokens.sand1, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button {
            store.saveTransaction()
        } label: {
            Text(mode == .deposit ? "Add it" : mode == .move ? "Move it" : "Log it")
                .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(store.canSubmitTransaction ? Tokens.ink : Tokens.sand4, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!store.canSubmitTransaction)
        .accessibilityIdentifier("submit-transaction")
    }
}

private enum TransactionCardPicker: String, Identifiable {
    case source
    case destination

    var id: String { rawValue }
}
