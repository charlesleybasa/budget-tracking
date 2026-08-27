import SwiftUI
import UIKit

struct CardDetailView: View {
    @Bindable var store: WalletStore
    var cardID: String
    @State private var flipped = false

    private var card: Card? { store.snapshot.cards.first { $0.id == cardID } }
    private var transactions: [Transaction] { store.snapshot.tx.filter { $0.cardId == cardID }.sorted { $0.at > $1.at } }

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            if let card {
                VStack(spacing: 0) {
                    navigation(card)
                    cardStage(card)
                    detailSheet(card)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func navigation(_ card: Card) -> some View {
        HStack {
            circleButton("arrow.left", label: "Back to home", action: store.popRoute)
            Spacer()
            Text(card.nick)
                .font(AppFont.outfit(14, weight: .semibold, relativeTo: .subheadline))
                .lineLimit(1).frame(maxWidth: 190)
            Spacer()
            circleButton("pencil", label: "Redesign \(card.nick)") { store.openEditor(cardID: card.id) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Tokens.dark3, in: Circle())
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityLabel(label)
    }

    private func cardStage(_ card: Card) -> some View {
        ZStack {
            detailFront(card)
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 90 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .allowsHitTesting(!flipped)
                .onTapGesture { setFlipped(true) }
            cardBack(card)
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : -90), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .allowsHitTesting(flipped)
                .onTapGesture { setFlipped(false) }
        }
        .frame(width: 320, height: 196)
        .shadow(color: .black.opacity(0.45), radius: 17, y: 10)
        .overlay(alignment: .bottomTrailing) {
            Label(flipped ? "Card front" : "Receiving details", systemImage: "arrow.triangle.2.circlepath")
                .font(AppFont.outfit(9.5, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(.white.opacity(0.42))
                .offset(y: 17)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 18)
        .accessibilityLabel(flipped ? "\(card.nick). Show card front" : "\(card.nick). Show receiving details")
    }

    private func detailFront(_ card: Card) -> some View {
        CardFaceView(card: card, privateMode: store.snapshot.privacy)
            .accessibilityIdentifier("card-detail-front")
            .accessibilityHint("Double tap to show receiving details")
    }

    private func cardBack(_ card: Card) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#17171b"), Tokens.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("RECEIVE MONEY").font(AppFont.outfit(10.5, weight: .semibold, relativeTo: .caption2)).tracking(1.25).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 28).background(.white.opacity(0.1), in: Circle())
                }
                if let qr = card.qr {
                    Button { store.qrViewerCardID = card.id } label: {
                        ResourceImage(reference: qr, contentMode: .fit).frame(width: 70, height: 70).padding(4).background(.white, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(PesolitaPressStyle()).frame(maxWidth: .infinity)
                }
                Spacer()
                if let account = card.accountNumber, !account.isEmpty {
                    Button {
                        UIPasteboard.general.string = account
                        store.showToast("Receiving number copied.")
                        FeedbackCenter.success()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACCOUNT NUMBER · TAP TO COPY").font(AppFont.outfit(9, weight: .medium, relativeTo: .caption2)).tracking(1).foregroundStyle(.white.opacity(0.45))
                            Text(account).font(AppFont.outfit(17, weight: .bold, relativeTo: .headline)).foregroundStyle(.white)
                        }
                    }.buttonStyle(.plain)
                } else if card.qr == nil {
                    Button { store.openEditor(cardID: card.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Nothing to show yet").font(AppFont.outfit(14, weight: .bold, relativeTo: .subheadline))
                            Text("Add your QR or account number so people can pay you").font(AppFont.outfit(11.5, relativeTo: .caption)).foregroundStyle(.white.opacity(0.5))
                        }
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
        }
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
    }

    private func setFlipped(_ value: Bool) {
        guard flipped != value else { return }
        withAnimation(Tokens.flipCurve(0.62)) { flipped = value }
        FeedbackCenter.snap()
    }

    private func detailSheet(_ card: Card) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                spendingSummary(card)
                actionRow(card)
                Text("History")
                    .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline)).foregroundStyle(Tokens.ink).tracking(-0.2)
                    .padding(.top, 24)
                if transactions.isEmpty { emptyHistory }
                else { transactionHistory(card) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
        .preferredColorScheme(.light)
    }

    private func spendingSummary(_ card: Card) -> some View {
        let spent = WalletMetrics.spentThisMonth(cardID: card.id, transactions: store.snapshot.tx)
        let limit = card.goal ?? (card.limit > 0 ? card.limit : max(card.bal, 1))
        let progress = card.goal.map { min(1, card.bal / max($0, 1)) } ?? min(1, spent / max(limit, 1))
        return HStack(spacing: 11) {
            ProgressRingView(progress: progress, label: "\(Int((progress * 100).rounded()))%")
                .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 0) {
                Text(card.goal == nil ? "SPENT THIS MONTH" : "GOAL PROGRESS")
                    .font(AppFont.outfit(11, weight: .medium, relativeTo: .caption)).tracking(1).foregroundStyle(Tokens.muted2)
                (Text(MoneyFormat.balance(card.goal == nil ? spent : card.bal)).font(AppFont.outfit(20, weight: .bold, relativeTo: .title3)) +
                 Text(" of \(MoneyFormat.balance(limit))").font(AppFont.outfit(13, weight: .medium, relativeTo: .caption)).foregroundColor(Tokens.muted2))
                    .foregroundStyle(Tokens.ink).padding(.top, 6).lineLimit(1).minimumScaleFactor(0.65)
                Text(progress < 0.8 ? "On track for the month." : "Getting close to the limit.")
                    .font(AppFont.outfit(11.5, relativeTo: .caption)).foregroundStyle(Tokens.muted1).padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func actionRow(_ card: Card) -> some View {
        HStack(spacing: 8) {
            actionButton("Log spend", icon: "arrow.down.to.line", background: Tokens.ink, foreground: .white) { store.openTransaction(.withdraw, cardID: card.id) }
            actionButton("Top up", icon: "arrow.up.to.line", background: Tokens.accent, foreground: Tokens.ink) { store.openTransaction(.deposit, cardID: card.id) }
            actionButton("Move money", icon: "arrow.left.arrow.right", background: Tokens.sand1, foreground: Tokens.ink) { store.openTransfer(from: card.id) }
        }
        .padding(.top, 14)
    }

    private func actionButton(_ title: String, icon: String, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(AppFont.outfit(13, weight: .semibold, relativeTo: .caption)).lineLimit(2)
            }
            .foregroundStyle(foreground).frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 7).background(background, in: Capsule())
        }.buttonStyle(PesolitaPressStyle())
    }

    private var emptyHistory: some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .flyingIdle, size: 118).frame(width: 118, height: 118).padding(.bottom, 4)
            Text("Nothing on this card yet.").font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline)).foregroundStyle(Tokens.ink)
            Text("Log a spend or a top up and it shows up here immediately.")
                .font(AppFont.outfit(12.5, relativeTo: .caption)).foregroundStyle(Tokens.muted2).multilineTextAlignment(.center).lineSpacing(3).padding(.top, 7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12).padding(.top, 22).padding(.bottom, 30)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 26)
    }

    private func transactionHistory(_ card: Card) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(WalletMetrics.dayGroups(transactions)) { group in
                HStack {
                    Text(WalletMetrics.dayLabel(group.day).uppercased())
                    Spacer()
                    Text(MoneyFormat.balance(group.total))
                }
                .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption)).tracking(0.8).foregroundStyle(Tokens.muted3).padding(.top, 16)
                ForEach(group.transactions) { transaction in
                    TransactionRowView(transaction: transaction, card: card) { store.openTransactionEditor(transaction.id) }
                    if transaction.id != group.transactions.last?.id { Divider() }
                }
            }
        }
    }
}
