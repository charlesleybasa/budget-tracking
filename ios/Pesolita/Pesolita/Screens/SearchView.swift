import SwiftUI

struct SearchView: View {
    @Bindable var store: WalletStore
    @FocusState private var focused: Bool

    private var results: [Transaction] { store.searchResults }
    private var groups: [TransactionDayGroup] { WalletMetrics.dayGroups(results) }
    private var hasFilters: Bool { !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.searchFilter != .all }
    private var moneyOut: Double { results.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) } }
    private var moneyIn: Double { results.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                searchHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(hasFilters ? "Search results" : "Recent activity")
                                    .font(AppFont.outfit(18, weight: .bold, relativeTo: .headline)).tracking(-0.4)
                                Text("\(results.count) \(results.count == 1 ? "transaction" : "transactions")")
                                    .font(AppFont.outfit(12, relativeTo: .caption)).foregroundStyle(Tokens.muted2)
                            }
                            Spacer()
                            if hasFilters {
                                Button("Reset", action: reset)
                                    .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption))
                                    .foregroundStyle(Tokens.ink)
                                    .padding(.horizontal, 13).frame(minHeight: 36).background(Tokens.sand2, in: Capsule())
                                    .buttonStyle(PesolitaPressStyle())
                            }
                        }

                        if !results.isEmpty {
                            HStack(spacing: 9) {
                                totalTile("Money out", amount: moneyOut, icon: "arrow.down", tint: Tokens.ink, background: Tokens.sand1)
                                totalTile("Money in", amount: moneyIn, icon: "arrow.up", tint: Tokens.green, background: Color(hex: "#edf8f3"))
                            }
                            .padding(.top, 16)
                        }

                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(WalletMetrics.dayLabel(group.day).uppercased())
                                    .font(AppFont.outfit(10.5, weight: .semibold, relativeTo: .caption2))
                                    .tracking(0.95)
                                    .foregroundStyle(Tokens.muted3)
                                VStack(spacing: 0) {
                                    ForEach(group.transactions) { transaction in
                                        TransactionRowView(transaction: transaction, card: store.snapshot.cards.first { $0.id == transaction.cardId }, showCard: true) {
                                            store.openTransactionEditor(transaction.id)
                                        }
                                        if transaction.id != group.transactions.last?.id { Divider() }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.line3))
                            }
                            .padding(.top, 21)
                        }

                        if results.isEmpty { emptyState }
                    }
                    .foregroundStyle(Tokens.ink)
                    .padding(.horizontal, 20)
                    .padding(.top, 19)
                    .padding(.bottom, 112)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.light)
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACTIVITY")
                .font(AppFont.outfit(10.5, weight: .bold, relativeTo: .caption2)).tracking(1.25).foregroundStyle(Tokens.accent)
            Text("Find a transaction")
                .font(AppFont.outfit(23, weight: .bold, relativeTo: .title2)).tracking(-0.8).foregroundStyle(.white).padding(.top, 8)
            Text("Search by merchant, note, or category.")
                .font(AppFont.outfit(12.5, relativeTo: .caption)).foregroundStyle(.white.opacity(0.52)).padding(.top, 6)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(Tokens.muted2)
                TextField("Coffee, load, last Tuesday…", text: $store.searchQuery)
                    .focused($focused)
                    .font(AppFont.outfit(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(Tokens.ink)
                    .submitLabel(.search)
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                        FeedbackCenter.tap()
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tokens.muted1)
                            .frame(width: 34, height: 34).background(Tokens.sand2, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 15)
            .padding(.trailing, 10)
            .frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 15, y: 8)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(focused ? Tokens.accent.opacity(0.5) : .clear, lineWidth: 3))
            .padding(.top, 17)

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(SearchFilter.allCases) { filter in
                        Button {
                            store.searchFilter = filter
                            FeedbackCenter.selectionChanged()
                        } label: {
                            Text(filter.rawValue)
                                .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(store.searchFilter == filter ? Tokens.ink : .white.opacity(0.75))
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(store.searchFilter == filter ? Tokens.accent : .white.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(PesolitaPressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .contentMargins(.horizontal, -20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.top, 9)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Tokens.ink, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private func totalTile(_ title: String, amount: Double, icon: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                .frame(width: 30, height: 30).background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppFont.outfit(10.5, weight: .medium, relativeTo: .caption2)).foregroundStyle(Tokens.muted2)
                Text(MoneyFormat.balance(amount)).font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(background, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            if store.snapshot.tx.isEmpty {
                SpriteAnimationView(spec: .idleSteady, size: 96)
                    .frame(width: 96, height: 96)
                    .padding(.bottom, 12)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(Tokens.muted1)
                    .frame(width: 50, height: 50).background(.white, in: RoundedRectangle(cornerRadius: 17)).shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                    .padding(.bottom, 16)
            }
            Text(store.snapshot.tx.isEmpty ? "Your activity will show up here" : !store.searchQuery.isEmpty ? "No matches for “\(store.searchQuery.trimmingCharacters(in: .whitespaces))”" : "No transactions in this filter")
                .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.snapshot.tx.isEmpty ? "Log your first spend or top up to start building your history." : "Try another word or reset the filters to see everything again.")
                .font(AppFont.outfit(13, relativeTo: .subheadline)).foregroundStyle(Tokens.muted2)
                .multilineTextAlignment(.center).lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.top, 7)
            Button(store.snapshot.tx.isEmpty ? "Log a spend" : "Show all activity") {
                store.snapshot.tx.isEmpty ? store.openTransaction(.withdraw) : reset()
            }
            .font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(.white)
            .padding(.horizontal, 18).frame(minHeight: 44).background(Tokens.ink, in: Capsule()).buttonStyle(PesolitaPressStyle()).padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, store.snapshot.tx.isEmpty ? 24 : 42)
        .padding(.bottom, 42)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 22)
    }

    private func reset() {
        store.searchQuery = ""
        store.searchFilter = .all
        FeedbackCenter.tap()
    }
}
