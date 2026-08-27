import SwiftUI

struct HomeView: View {
    @Bindable var store: WalletStore
    @State private var scrollID: String?
    @State private var cardsDealt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if store.snapshot.cards.isEmpty { emptyWallet }
                else if store.snapshot.homeLayout == .deck { deckLayout }
                else { stackLayout }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            scrollID = store.snapshot.activeId
            dealCardsIn()
        }
        .onDisappear {
            withAnimation(nil) { cardsDealt = false }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName)")
                    .font(AppFont.outfit(11.5, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.42))
                Text(store.snapshot.cards.isEmpty ? "Your wallet" : "Total \(store.snapshot.privacy ? "₱•••••" : MoneyFormat.balance(store.totalBalance))")
                    .font(AppFont.outfit(19, weight: .bold, relativeTo: .headline))
                    .tracking(-0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if !store.snapshot.cards.isEmpty {
                    roundButton(
                        store.snapshot.homeLayout == .deck ? "rectangle.split.2x1" : "rectangle.stack",
                        label: store.snapshot.homeLayout == .deck ? "Switch to wallet stack" : "Switch to card deck"
                    ) {
                        withAnimation(Tokens.easeSpring(0.42)) {
                            store.setHomeLayout(store.snapshot.homeLayout == .deck ? .stack : .deck)
                        }
                    }
                    roundButton(store.snapshot.privacy ? "eye.slash" : "eye", label: store.snapshot.privacy ? "Show balances" : "Hide balances", action: store.togglePrivacy)
                }
                roundButton("plus", label: "New card") { store.openEditor(cardID: nil) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Tokens.dark3, in: Circle())
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityLabel(label)
    }

    private var deckLayout: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                deck
                dots
                HStack(spacing: 10) {
                    quickPill("Spend", icon: "arrow.up.right") { store.openTransaction(.withdraw) }
                    quickPill("Top up", icon: "arrow.down.left") { store.openTransaction(.deposit) }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 15)
                activityPanel
            }
        }
        .scrollIndicators(.hidden)
    }

    private var deck: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(store.snapshot.cards) { card in
                    Button { store.showCardDetail(card.id) } label: {
                        CardFaceView(card: card, privateMode: store.snapshot.privacy)
                            .frame(width: 320, height: 196)
                            .shadow(color: .black.opacity(0.45), radius: 17, y: 10)
                    }
                    .buttonStyle(PesolitaPressStyle())
                    .id(card.id)
                    .accessibilityIdentifier("wallet-card-\(card.id)")
                }
                Button { store.openEditor(cardID: nil) } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus").frame(width: 38, height: 38).background(.white.opacity(0.09), in: Circle())
                        Text("Add a card").font(AppFont.outfit(12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 320, height: 196)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [7])))
                }
                .buttonStyle(PesolitaPressStyle())
            }
            .scrollTargetLayout()
        }
        .contentMargins(.leading, 22, for: .scrollContent)
        .contentMargins(.trailing, 60, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrollID, anchor: .leading)
        .onChange(of: scrollID) { _, id in if let id { store.setActiveCard(id) } }
        .frame(height: 196)
        .offset(y: cardsDealt ? 0 : 54)
        .scaleEffect(cardsDealt ? 1 : 0.94)
    }

    private var dots: some View {
        HStack(spacing: 19) {
            ForEach(store.snapshot.cards) { card in
                Button {
                    withAnimation(Tokens.easeOut(0.3)) { scrollID = card.id }
                } label: {
                    Capsule()
                        .fill(card.id == store.snapshot.activeId ? Tokens.accent : .white.opacity(0.24))
                        .frame(width: card.id == store.snapshot.activeId ? 18 : 5, height: 5)
                        .frame(width: 24, height: 29)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 41)
        .animation(Tokens.easeOut(0.3), value: store.snapshot.activeId)
    }

    private func quickPill(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
                Text(title)
                    .font(AppFont.outfit(14, weight: .semibold, relativeTo: .subheadline))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Tokens.dark3, in: Capsule())
        }
        .buttonStyle(PesolitaPressStyle())
    }

    private var stackLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Button { store.selectTab(.insights) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("SAFE TODAY")
                                .font(AppFont.outfit(9.5, weight: .medium, relativeTo: .caption2)).tracking(1.05).foregroundStyle(.white.opacity(0.4))
                            Text(store.snapshot.privacy ? "₱•••••" : MoneyFormat.balance(safeToday))
                                .font(AppFont.outfit(21, weight: .bold, relativeTo: .title3)).tracking(-0.5)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 15)
                        .frame(height: 82)
                        .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PesolitaPressStyle())

                    Button { store.openTransaction(.withdraw) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("QUICK")
                                .font(AppFont.outfit(9.5, weight: .medium, relativeTo: .caption2)).tracking(1.05).foregroundStyle(Tokens.ink.opacity(0.5))
                            Label("Log spend", systemImage: "arrow.up.right")
                                .font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline))
                        }
                        .foregroundStyle(Tokens.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 15)
                        .frame(height: 82)
                        .background(Tokens.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PesolitaPressStyle())
                }

                Text("Your cards")
                    .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline))
                    .padding(.top, 18)
                Text("Tap to open · tap again for history")
                    .font(AppFont.outfit(11.5, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)

                walletStack
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 104)
        }
        .scrollIndicators(.hidden)
    }

    private var walletStack: some View {
        let cards = store.snapshot.cards
        let stackHeight = stackOffset(for: cards.count) + 196
        return ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                StackWalletCard(
                    card: card,
                    privateMode: store.snapshot.privacy,
                    open: card.id == store.snapshot.activeId,
                    onTap: {
                        if card.id == store.snapshot.activeId { store.showCardDetail(card.id) }
                        else { withAnimation(Tokens.easeOut(0.44)) { store.setActiveCard(card.id) } }
                    },
                    onTopUp: { store.openTransaction(.deposit, cardID: card.id) },
                    onSpend: { store.openTransaction(.withdraw, cardID: card.id) }
                )
                // Match the web's inner `bwDeal` transform so each card rises
                // without compressing the stack positions around it.
                .scaleEffect(cardsDealt ? 1 : 0.94)
                .offset(y: stackOffset(for: index) + (cardsDealt ? 0 : 54))
                .zIndex(Double(index))
            }

            Button { store.openEditor(cardID: nil) } label: {
                Label("Add a card", systemImage: "plus")
                    .font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(Capsule().stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [7])))
            }
            .buttonStyle(PesolitaPressStyle())
            .offset(y: stackHeight + 14)
            .zIndex(Double(cards.count + 1))
        }
        .frame(height: stackHeight + 66, alignment: .top)
        .animation(Tokens.easeOut(0.44), value: store.snapshot.activeId)
    }

    private func stackOffset(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        return store.snapshot.cards.prefix(index).reduce(0) { total, card in total + (card.id == store.snapshot.activeId ? 208 : 84) }
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let card = store.activeCard { safeCard(card) }
            Text("Recent activity")
                .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline))
                .foregroundStyle(Tokens.ink)
                .padding(.top, 24)
            if store.snapshot.tx.isEmpty {
                VStack(spacing: 0) {
                    SpriteAnimationView(spec: .flyingIdle, size: 118)
                        .padding(.bottom, 4)
                    Text("Nothing logged yet.")
                        .font(AppFont.outfit(14.5, weight: .bold, relativeTo: .subheadline))
                        .foregroundStyle(Tokens.ink)
                    Text("Tap the blue button and put in what you just spent. Two taps, and this fills up.")
                        .font(AppFont.outfit(12.5, relativeTo: .caption))
                        .foregroundStyle(Tokens.muted2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.top, 7)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 10)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.snapshot.tx.sorted { $0.at > $1.at }.prefix(6))) { transaction in
                        TransactionRowView(transaction: transaction, card: store.snapshot.cards.first { $0.id == transaction.cardId }) {
                            store.openTransactionEditor(transaction.id)
                        }
                        if transaction.id != store.snapshot.tx.sorted(by: { $0.at > $1.at }).prefix(6).last?.id { Divider() }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 108)
        .frame(maxWidth: .infinity, minHeight: 430, alignment: .topLeading)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private func safeCard(_ card: Card) -> some View {
        let progress = min(1, max(0, WalletMetrics.cardProgress(card, transactions: store.snapshot.tx)))
        return Button { store.selectTab(.insights) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("SAFE TO SPEND TODAY")
                    Spacer()
                    Text("\(daysLeft) days left in \(Date.now.formatted(.dateTime.month(.wide)))")
                }
                .font(AppFont.outfit(11, weight: .medium, relativeTo: .caption))
                .tracking(0.7)
                .foregroundStyle(Tokens.muted2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(store.snapshot.privacy ? "₱•••••" : MoneyFormat.balance(safeToday))
                        .font(AppFont.outfit(32, weight: .bold, relativeTo: .title))
                        .tracking(-1)
                    Text("on \(card.nick)")
                        .font(AppFont.outfit(12.5, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(Tokens.muted2)
                }
                .foregroundStyle(Tokens.ink)
                .padding(.top, 8)
                Capsule().fill(Tokens.sand4).frame(height: 7).overlay(alignment: .leading) {
                    Capsule().fill(progress > 0.82 ? Tokens.red : Tokens.green).frame(maxWidth: max(7, 330 * progress))
                }
                .padding(.top, 12)
                Text("Comfortable. Your money has room to breathe.")
                    .font(AppFont.outfit(12, relativeTo: .caption))
                    .foregroundStyle(Tokens.muted1)
                    .padding(.top, 9)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
    }

    private var emptyWallet: some View {
        VStack(spacing: 12) {
            ZStack {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(index == 2 ? Tokens.accent.opacity(0.06) : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(index == 2 ? Tokens.accent.opacity(0.55) : .white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: index == 2 ? [] : [6])))
                        .frame(width: 118, height: 74)
                        .rotationEffect(.degrees(index == 0 ? -9 : index == 1 ? 4 : 0))
                        .offset(y: index == 0 ? 16 : index == 1 ? 8 : 0)
                }
            }
            .frame(width: 150, height: 108)
            Text("No cards yet.").font(AppFont.outfit(24, weight: .black, relativeTo: .title2))
            Text("Make one for each pocket of your money — your bank card, e-wallet, or the cash actually in your wallet. Nothing connects to a bank.")
                .font(AppFont.outfit(13.5, relativeTo: .subheadline)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(3)
            Button("Make your first card") { store.openEditor(cardID: nil) }
                .font(AppFont.outfit(14, weight: .bold, relativeTo: .subheadline)).foregroundStyle(Tokens.ink)
                .padding(.horizontal, 22).frame(minHeight: 48).background(Tokens.accent, in: Capsule()).buttonStyle(PesolitaPressStyle())
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var firstName: String { store.snapshot.userName.split(separator: " ").first.map(String.init) ?? "there" }

    private func dealCardsIn() {
        guard !reduceMotion else {
            cardsDealt = true
            return
        }
        withAnimation(nil) { cardsDealt = false }
        Task { @MainActor in
            await Task.yield()
            withAnimation(Tokens.dealCurve(0.6)) { cardsDealt = true }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) { case 5..<12: "Good morning"; case 12..<18: "Good afternoon"; default: "Good evening" }
    }
    private var safeToday: Double { store.activeCard.map { WalletMetrics.safeToSpend($0, transactions: store.snapshot.tx) } ?? 0 }
    private var daysLeft: Int {
        let calendar = Calendar.current
        let count = calendar.range(of: .day, in: .month, for: .now)?.count ?? 1
        return max(1, count - calendar.component(.day, from: .now) + 1)
    }
}

private struct StackWalletCard: View {
    var card: Card
    var privateMode: Bool
    var open: Bool
    var onTap: () -> Void
    var onTopUp: () -> Void
    var onSpend: () -> Void

    var body: some View {
        let theme = CardTheme(art: card.art)
        ZStack {
            CardArtView(art: card.art, cornerRadius: 22, stretchesToFill: true)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.kind.rawValue.uppercased())
                            .font(AppFont.outfit(9.5, weight: .semibold, relativeTo: .caption2)).tracking(1.15).foregroundStyle(theme.dimmed)
                        Text(card.nick)
                            .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline)).tracking(-0.2).foregroundStyle(theme.foreground).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(card.goal == nil ? "LEFT" : "SAVED")
                            .font(AppFont.outfit(9, weight: .medium, relativeTo: .caption2)).tracking(1).foregroundStyle(theme.dimmed)
                        Text(privateMode ? "₱•••••" : MoneyFormat.balance(card.bal))
                            .font(AppFont.outfit(21, weight: .bold, relativeTo: .title3)).tracking(-0.7).foregroundStyle(theme.foreground).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARD").font(AppFont.outfit(8.5, weight: .medium, relativeTo: .caption2)).tracking(0.9).foregroundStyle(theme.dimmed)
                        Text(card.last4.isEmpty ? "No number" : "•••• •••• \(card.last4)")
                            .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(theme.foreground)
                    }
                    Spacer()
                    if open {
                        HStack(spacing: 7) {
                            miniButton("Top up", foreground: theme.foreground, background: theme.useDarkText ? Tokens.ink.opacity(0.10) : .white.opacity(0.20), action: onTopUp)
                            miniButton("Spend", foreground: theme.useDarkText ? .white : Tokens.ink, background: theme.useDarkText ? Tokens.ink : .white, action: onSpend)
                        }
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            if card.frozen {
                Color.blue.opacity(0.12)
                Text("FROZEN").font(AppFont.outfit(11, weight: .semibold, relativeTo: .caption)).tracking(0.7).padding(.horizontal, 13).frame(height: 28).background(Tokens.ink.opacity(0.72), in: Capsule())
            }
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.38), radius: open ? 16 : 8, y: 7)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(card.nick), \(privateMode ? "balance hidden" : MoneyFormat.balance(card.bal))")
        .accessibilityAction(named: "Open card", onTap)
    }

    private func miniButton(_ title: String, foreground: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption)).foregroundStyle(foreground).padding(.horizontal, 13).frame(height: 32).background(background, in: Capsule())
        }
        .buttonStyle(PesolitaPressStyle())
    }
}
