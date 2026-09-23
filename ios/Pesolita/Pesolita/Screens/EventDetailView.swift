import SwiftUI

/// One event — what it cost, who still owes, and every spend inside it.
///
/// Settling here is the same action as everywhere else: it tops up a real card, because the
/// money really moved.
struct EventDetailView: View {
    @Bindable var store: WalletStore
    let eventID: String
    @State private var sharing: SharePayload?
    @State private var confirmDelete = false
    @State private var expandedPeople: Set<String> = []

    var body: some View {
        if let event = EventMetrics.find(store.snapshot.events, id: eventID) {
            content(for: event)
        } else {
            // A deleted event leaves the screen without a subject.
            VStack(spacing: 10) {
                Text("That event is gone")
                    .font(AppFont.outfit(16, weight: .bold))
                    .foregroundStyle(Tokens.text)
                Text("It was removed. The spends inside it stayed in your wallet.")
                    .font(AppFont.outfit(13))
                    .foregroundStyle(Tokens.muted1)
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.background)
        }
    }

    private func content(for event: EventGroup) -> some View {
        let totals = EventMetrics.totals(store.snapshot.tx, eventID: event.id)
        let shares = EventMetrics.shares(store.snapshot.tx, eventID: event.id,
                                         people: store.snapshot.people,
                                         ownerName: store.snapshot.userName)
        let rows = EventMetrics.transactions(store.snapshot.tx, eventID: event.id).filter { $0.amount < 0 }
        let maxShare = max(1, shares.map(\.amount).max() ?? 1)
        // Only people who still owe inside this event, so the section is a to-do not a list.
        let owing = SplitMath.debts(
            transactions: store.snapshot.tx.filter { $0.eventId == event.id },
            people: store.snapshot.people
        )

        var stats: [(String, String, Bool)] = [
            ("Event total", "₱\(MoneyFormat.amount(totals.total))", false),
            ("Your share", "₱\(MoneyFormat.amount(totals.mine))", false),
        ]
        if totals.owed > 0 {
            stats.append(("Still out", "₱\(MoneyFormat.amount(totals.owed))", true))
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SocialHeader(
                    emoji: event.emoji,
                    title: event.name,
                    subtitle: EventMetrics.dateLabel(event)
                        + (totals.count > 0 ? " · \(totals.count == 1 ? "1 spend" : "\(totals.count) spends")" : ""),
                    stats: stats
                )

                VStack(alignment: .leading, spacing: 22) {
                    if rows.isEmpty {
                        SocialEmptyState(
                            title: "Nothing in it yet",
                            message: event.endedAt == nil
                                ? "This event is running, so the next spend you log lands here on its own."
                                : "This event closed without anything logged against it."
                        )
                    } else {
                        if !owing.isEmpty {
                            section("Still to come back") {
                                VStack(spacing: 8) {
                                    ForEach(owing) { debt in owingRow(debt) }
                                }
                            }
                        }

                        section("Who carried what") {
                            VStack(spacing: 11) {
                                ForEach(shares) { share in
                                    bar(for: share, max: maxShare)
                                }
                            }
                        }

                        section("Every spend") {
                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { index, tx in
                                    spendRow(tx, showsDivider: index > 0)
                                }
                            }
                        }

                        Button {
                            sharing = SharePayload(
                                text: EventMetrics.summaryText(event: event, totals: totals, shares: shares)
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Share summary")
                                    .font(AppFont.outfit(13.5, weight: .bold))
                            }
                            .foregroundStyle(Tokens.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Tokens.text, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PesolitaPressStyle())
                    }

                    Button(confirmDelete ? "Tap again to remove — the spends stay" : "Remove this event") {
                        if confirmDelete { store.deleteEvent(event.id) } else { confirmDelete = true }
                    }
                    .font(AppFont.outfit(12.5, weight: .semibold))
                    .foregroundStyle(Tokens.negative)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .background(Tokens.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        // The bar shares the page colour so it reads as part of the hero, in either mode.
        .toolbarBackground(Tokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if event.endedAt == nil { store.closeEvent(event.id) } else { store.reopenEvent(event.id) }
                } label: {
                    Image(systemName: event.endedAt == nil ? "checkmark" : "arrow.counterclockwise")
                }
                .accessibilityLabel(event.endedAt == nil ? "Close this event" : "Reopen this event")
            }
        }
        .sheet(item: $sharing) { ActivityShareSheet(text: $0.text) }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(AppFont.outfit(15, weight: .bold))
                .foregroundStyle(Tokens.text)
            content()
        }
    }

    private func owingRow(_ debt: PersonDebt) -> some View {
        let isExpanded = expandedPeople.contains(debt.personId)
        
        return VStack(spacing: 0) {
            HStack(spacing: 11) {
                Text(SplitMath.initial(debt.name))
                    .font(AppFont.outfit(13, weight: .bold))
                    .foregroundStyle(Tokens.on(hex: debt.color))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: debt.color), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(debt.name)
                            .font(AppFont.outfit(13.5, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                            .lineLimit(1)
                        if debt.count > 1 {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Tokens.muted2)
                        }
                    }
                    Text("\(debt.count == 1 ? "1 spend" : "\(debt.count) spends") in this event")
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(1)
                }
                .layoutPriority(0)

                Spacer(minLength: 4)

                Text("₱\(MoneyFormat.amount(debt.amount))")
                    .font(AppFont.outfit(14, weight: .bold))
                    .foregroundStyle(Tokens.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Button("Paid me") { store.askSettle(personID: debt.personId) }
                    .font(AppFont.outfit(11.5, weight: .bold))
                    .foregroundStyle(Tokens.onAccent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Tokens.accent, in: Capsule())
                    .buttonStyle(.plain)
                    .fixedSize()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                guard debt.count > 1 else { return }
                withAnimation(.snappy) {
                    if isExpanded { expandedPeople.remove(debt.personId) }
                    else { expandedPeople.insert(debt.personId) }
                }
            }
            
            if isExpanded, debt.count > 1 {
                VStack(spacing: 8) {
                    ForEach(debt.unsettledSpends) { spend in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spend.transaction.note.trimmingCharacters(in: .whitespaces).isEmpty ? spend.transaction.cat.rawValue : spend.transaction.note)
                                    .font(AppFont.outfit(13, weight: .semibold))
                                    .foregroundStyle(Tokens.text)
                                    .lineLimit(1)
                                Text(Date(timeIntervalSince1970: spend.transaction.at).formatted(.dateTime.month().day()))
                                    .font(AppFont.outfit(11, weight: .medium))
                                    .foregroundStyle(Tokens.muted2)
                            }
                            Spacer()
                            Text("₱\(MoneyFormat.amount(spend.owedAmount))")
                                .font(AppFont.outfit(13, weight: .bold))
                                .foregroundStyle(Tokens.text)
                            Button("Settle") { store.askSettle(personID: debt.personId, transactionID: spend.transaction.id) }
                                .font(AppFont.outfit(11, weight: .bold))
                                .foregroundStyle(Tokens.text)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 28)
                                .background(Tokens.background, in: Capsule())
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Tokens.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bar(for share: EventShare, max maxShare: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(share.personId == SplitMath.meID ? "You" : share.name)
                    .font(AppFont.outfit(13, weight: .semibold))
                    .foregroundStyle(Tokens.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("₱\(MoneyFormat.amount(share.amount))"
                     + (share.owed > 0 ? " · ₱\(MoneyFormat.amount(share.owed)) owed" : ""))
                    .font(AppFont.outfit(12, weight: .medium))
                    .foregroundStyle(Tokens.muted1)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                Capsule()
                    .fill(share.personId == SplitMath.meID ? Tokens.accent : Color(hex: share.color))
                    .frame(width: geo.size.width * (share.amount / maxShare))
            }
            .frame(height: 8)
            .background(Tokens.dark3, in: Capsule())
        }
    }

    private func spendRow(_ tx: Transaction, showsDivider: Bool) -> some View {
        let parts = tx.split?.parts ?? []
        return VStack(spacing: 0) {
            if showsDivider { Divider().overlay(Tokens.line3) }
            Button {
                store.openTransactionEditor(tx.id)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.merchant)
                            .font(AppFont.outfit(13, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                            .lineLimit(1)
                        Text("\(tx.cat.rawValue) · \(WalletMetrics.dayLabel(Date(timeIntervalSince1970: tx.at / 1000)))")
                            .font(AppFont.outfit(11, weight: .medium))
                            .foregroundStyle(Tokens.muted2)
                    }

                    Spacer(minLength: 4)

                    if !parts.isEmpty {
                        HStack(spacing: -8) {
                            avatar(SplitMath.initial(store.snapshot.userName.isEmpty ? "You" : store.snapshot.userName),
                                   Tokens.textPrimary, foreground: Tokens.bgBase)
                            ForEach(parts.prefix(3)) { part in
                                let hex = store.snapshot.people.first { $0.id == part.personId }?.color ?? "#6d6d72"
                                avatar(SplitMath.initial(part.name), Color(hex: hex), foreground: Tokens.on(hex: hex))
                            }
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("₱\(MoneyFormat.amount(abs(tx.amount)))")
                            .font(AppFont.outfit(13.5, weight: .bold))
                            .foregroundStyle(Tokens.text)
                            .monospacedDigit()
                        if tx.split != nil {
                            Text("₱\(MoneyFormat.amount(SplitMath.spend(tx))) yours")
                                .font(AppFont.outfit(10.5, weight: .medium))
                                .foregroundStyle(Tokens.muted2)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
        }
    }

    /// `foreground` is explicit because a fill and its initial must never resolve to the same
    /// colour — the owner's avatar used `text` for both and rendered as a blank disc.
    private func avatar(_ initial: String, _ color: Color, foreground: Color) -> some View {
        Text(initial)
            .font(AppFont.outfit(9.5, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 22, height: 22)
            .background(color, in: Circle())
            // The ring matches the page, so overlapping avatars read as cut out of it.
            .overlay(Circle().strokeBorder(Tokens.bgBase, lineWidth: 1.5))
    }
}
