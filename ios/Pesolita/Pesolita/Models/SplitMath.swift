import Foundation

/// Splitting in Pesolita is an annotation on a spend the user already logged — "part of this
/// ₱1,200 was never mine" — not a second ledger. That reframe is why there is no debt graph
/// here and nothing to simplify: the wallet has exactly one owner, so every debt runs in one
/// direction, toward them.
///
/// Mirrors `lib/split.ts` on the web. Keep the two in step — a divergence would let the same
/// wallet report different figures on a phone and in a browser.
enum SplitMath {
    /// Avatar colours new people are assigned from, in order. Drawn from the app's own palette.
    static let personColors = [
        "#1d6ff2", "#0b8f6a", "#f0483e", "#7c3aed",
        "#ec4899", "#f97316", "#0891b2", "#ffca28",
    ]

    /// Reserved id for the wallet owner, so "me" can sit in a list of people without being one.
    static let meID = "me"

    /// Centavo-accurate rounding. Money maths in doubles drifts; every split lands through this.
    static func centavos(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    static func nextColor(existing: [Person]) -> String {
        personColors[existing.count % personColors.count]
    }

    static func initial(_ name: String) -> String {
        String(name.filter(\.isLetter).prefix(1)).uppercased().isEmpty
            ? "?"
            : String(name.filter(\.isLetter).prefix(1)).uppercased()
    }

    /// Split `total` evenly between the owner and `people`.
    ///
    /// ₱1,000 across three is ₱333.33 each and a centavo short. The remainder always goes to
    /// the wallet owner — the sheet says so out loud — rather than rotating between members the
    /// way Splitwise does. With one ledger owner that rule is both simpler and impossible to
    /// argue with, and deciding it here once stops it drifting between call sites.
    static func evenly(total: Double, people: [Person]) -> Split {
        let heads = Double(people.count + 1)
        let each = centavos(((total * 100) / heads).rounded(.down) / 100)
        let parts = people.map {
            SplitPart(personId: $0.id, name: $0.name, amount: each, settledAt: nil)
        }
        // Whatever the floor left behind lands on the owner, so the parts always sum to the bill.
        let mine = centavos(total - each * Double(people.count))
        return Split(mode: .even, mine: mine, parts: parts)
    }

    /// Split by shares — "Bea had two plates". The owner always holds one share.
    static func byShares(total: Double, people: [Person], shares: [String: Int]) -> Split {
        let totalShares = 1 + people.reduce(0) { $0 + max(0, shares[$1.id] ?? 1) }
        guard totalShares > 0 else { return evenly(total: total, people: people) }

        let parts = people.map { person -> SplitPart in
            let own = max(0, shares[person.id] ?? 1)
            let amount = centavos(((total * Double(own) * 100) / Double(totalShares)).rounded(.down) / 100)
            return SplitPart(personId: person.id, name: person.name, amount: amount, shares: own, settledAt: nil)
        }
        let mine = centavos(total - parts.reduce(0) { $0 + $1.amount })
        return Split(mode: .shares, mine: mine, parts: parts)
    }

    /// Split by exact amounts the user typed. The owner takes whatever is left over, which is
    /// what makes this mode safe to edit a field at a time: the split always sums to the bill,
    /// so there is no "₱20 unaccounted for" error state to design.
    static func byExact(total: Double, people: [Person], amounts: [String: Double]) -> Split {
        let parts = people.map {
            SplitPart(personId: $0.id, name: $0.name, amount: centavos(max(0, amounts[$0.id] ?? 0)), settledAt: nil)
        }
        let mine = centavos(total - parts.reduce(0) { $0 + $1.amount })
        return Split(mode: .exact, mine: mine, parts: parts)
    }

    /// Split 100% of the bill evenly among the selected people. The owner's share is zero.
    static func byTheirs(total: Double, people: [Person]) -> Split {
        let heads = Double(people.count)
        let each = centavos(((total * 100) / heads).rounded(.down) / 100)
        
        var parts = people.map {
            SplitPart(personId: $0.id, name: $0.name, amount: each, settledAt: nil)
        }
        
        // If 100/3 leaves a remainder, assign it to the first person so total is exact.
        let assigned = each * heads
        let remainder = centavos(total - assigned)
        if remainder > 0, !parts.isEmpty {
            parts[0].amount = centavos(parts[0].amount + remainder)
        }
        
        return Split(mode: .theirs, mine: 0, parts: parts)
    }

    static func build(mode: SplitMode, total: Double, people: [Person],
                      shares: [String: Int], amounts: [String: Double]) -> Split? {
        guard !people.isEmpty, total > 0 else { return nil }
        switch mode {
        case .even: return evenly(total: total, people: people)
        case .shares: return byShares(total: total, people: people, shares: shares)
        case .exact: return byExact(total: total, people: people, amounts: amounts)
        case .theirs: return byTheirs(total: total, people: people)
        }
    }

    /// Rescale an existing split after its transaction's amount was edited.
    ///
    /// Parts somebody has already paid back are left exactly as they are — money that has
    /// changed hands is not ours to quietly rewrite — so only the open parts move, and the
    /// owner absorbs whatever is left.
    static func rescale(_ previous: Split, to total: Double) -> Split {
        let settled = previous.parts.filter { $0.settledAt != nil }
        let open = previous.parts.filter { $0.settledAt == nil }
        let settledTotal = settled.reduce(0) { $0 + $1.amount }
        let remaining = max(0, centavos(total - settledTotal))

        let people = open.map { Person(id: $0.personId, name: $0.name, color: "#6d6d72") }
        let shares = Dictionary(uniqueKeysWithValues: open.map { ($0.personId, $0.shares ?? 1) })
        let amounts = Dictionary(uniqueKeysWithValues: open.map { ($0.personId, $0.amount) })
        let rebuilt = build(mode: previous.mode, total: remaining, people: people,
                            shares: shares, amounts: amounts)
            ?? Split(mode: previous.mode, mine: remaining, parts: [])
        let byId = Dictionary(uniqueKeysWithValues: rebuilt.parts.map { ($0.personId, $0) })

        // Original order is preserved so the editor's rows do not reshuffle under the user.
        let parts = previous.parts.map { part -> SplitPart in
            guard part.settledAt == nil, let next = byId[part.personId] else { return part }
            var updated = part
            updated.amount = next.amount
            updated.shares = next.shares ?? part.shares
            return updated
        }
        return Split(mode: previous.mode, mine: rebuilt.mine, parts: parts)
    }

    /// What this transaction actually cost the wallet owner, signed the same way `amount` is.
    ///
    /// `amount` stays the full bill because the card really did lose that much and the balance
    /// must never lie. Every spend analytic reads this instead, or the app tells the user they
    /// spent ₱1,200 on dinner when they spent ₱400 and lent ₱800.
    static func myShare(_ transaction: Transaction) -> Double {
        guard let split = transaction.split else { return transaction.amount }
        return transaction.amount < 0 ? -split.mine : split.mine
    }

    /// Money the owner actually spent on this entry, as a positive figure. Zero for anything
    /// that is not a spend.
    static func spend(_ transaction: Transaction) -> Double {
        let share = myShare(transaction)
        return share < 0 ? abs(share) : 0
    }

    static func outstanding(_ split: Split?) -> [SplitPart] {
        (split?.parts ?? []).filter { $0.settledAt == nil }
    }
}

/// Everything one person still owes the wallet owner.
struct UnsettledSpend: Identifiable, Sendable {
    var id: String { transaction.id }
    var transaction: Transaction
    var owedAmount: Double
}

struct PersonDebt: Identifiable, Sendable {
    var personId: String
    var name: String
    var color: String
    var handle: String?
    var photoSrc: String?
    var amount: Double
    /// How many spends it is spread across — the reason a row can say "3 spends".
    var count: Int
    var lastEventId: String?
    var unsettledSpends: [UnsettledSpend]
    var id: String { personId }
}

extension SplitMath {
    /// Who owes the wallet owner, and how much. One direction only — there is no "you owe
    /// them" side to this ledger, which is what removes any need for debt simplification.
    static func debts(transactions: [Transaction], people: [Person]) -> [PersonDebt] {
        let byId = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        var totals: [String: PersonDebt] = [:]
        var order: [String] = []

        for transaction in transactions {
            for part in outstanding(transaction.split) {
                let spend = UnsettledSpend(transaction: transaction, owedAmount: part.amount)
                
                if var existing = totals[part.personId] {
                    existing.amount = centavos(existing.amount + part.amount)
                    existing.count += 1
                    existing.unsettledSpends.append(spend)
                    if existing.lastEventId == nil { existing.lastEventId = transaction.eventId }
                    totals[part.personId] = existing
                } else {
                    let person = byId[part.personId]
                    totals[part.personId] = PersonDebt(
                        personId: part.personId,
                        // The part's own snapshot wins for a deleted person, so history reads.
                        name: person?.name ?? part.name,
                        color: person?.color ?? "#6d6d72",
                        handle: person?.handle,
                        photoSrc: person?.photoSrc,
                        amount: part.amount,
                        count: 1,
                        lastEventId: transaction.eventId,
                        unsettledSpends: [spend]
                    )
                    order.append(part.personId)
                }
            }
        }

        return order.compactMap { totals[$0] }
            .filter { $0.amount > 0.004 }
            .sorted { $0.amount > $1.amount }
    }

    static func totalOwed(_ transactions: [Transaction]) -> Double {
        centavos(transactions.reduce(0) { sum, transaction in
            sum + outstanding(transaction.split).reduce(0) { $0 + $1.amount }
        })
    }

    /// The reminder text the share sheet sends. Deliberately plain and a little apologetic —
    /// a message about money that reads as automated is one people do not send.
    static func reminder(for debt: PersonDebt, ownerName: String) -> String {
        let who = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = who.isEmpty ? "" : " — \(who)"
        let spends = debt.count == 1 ? "spend" : "\(debt.count) spends"
        
        let spendNames = debt.unsettledSpends.compactMap { tx -> String? in
            let note = tx.transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? tx.transaction.cat.rawValue : note
        }
        
        var details = ""
        if spendNames.count == 1 {
            details = " (\(spendNames[0]))"
        } else if spendNames.count > 1 {
            if spendNames.count > 2 {
                details = " (\(spendNames[0]), \(spendNames[1]) and \(spendNames.count - 2) others)"
            } else {
                details = " (\(spendNames[0]) and \(spendNames[1]))"
            }
        }
        
        return "Hi \(debt.name)! Sorry to bug you — that's ₱\(MoneyFormat.amount(debt.amount)) from our \(spends)\(details) together whenever you get a chance\(signature)"
    }
}

// MARK: - Events

/// What one event cost, and how much of it is still out with other people.
struct EventTotals: Sendable {
    var total: Double = 0
    var mine: Double = 0
    var owed: Double = 0
    var settled: Double = 0
    var count: Int = 0
}

/// One person's slice of a whole event, the owner included.
struct EventShare: Identifiable, Sendable {
    var personId: String
    var name: String
    var color: String
    var amount: Double
    var owed: Double
    var id: String { personId }
}

enum EventMetrics {
    /// Where a shared summary points people who do not have the app yet.
    static let appStoreURL = "https://apps.apple.com/ph/app/pesolita/id6805788143"

    static func find(_ events: [EventGroup], id: String?) -> EventGroup? {
        guard let id else { return nil }
        return events.first { $0.id == id }
    }

    /// The event a new spend should default into: the most recently started one still running.
    static func running(_ events: [EventGroup]) -> EventGroup? {
        events.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
    }

    /// Running events lead, then most recently started.
    static func sorted(_ events: [EventGroup]) -> [EventGroup] {
        events.sorted { a, b in
            if (a.endedAt == nil) != (b.endedAt == nil) { return a.endedAt == nil }
            return a.startedAt > b.startedAt
        }
    }

    static func transactions(_ transactions: [Transaction], eventID: String) -> [Transaction] {
        transactions.filter { $0.eventId == eventID }
    }

    static func totals(_ transactions: [Transaction], eventID: String) -> EventTotals {
        let rows = self.transactions(transactions, eventID: eventID)
        var totals = EventTotals(count: rows.count)
        for row in rows where row.amount < 0 {
            totals.total += abs(row.amount)
            totals.mine += SplitMath.spend(row)
            for part in row.split?.parts ?? [] {
                if part.settledAt != nil { totals.settled += part.amount } else { totals.owed += part.amount }
            }
        }
        totals.total = SplitMath.centavos(totals.total)
        totals.mine = SplitMath.centavos(totals.mine)
        totals.owed = SplitMath.centavos(totals.owed)
        totals.settled = SplitMath.centavos(totals.settled)
        return totals
    }

    /// Per-person totals inside one event, ordered by size so the bars read as a ranking.
    static func shares(_ transactions: [Transaction], eventID: String,
                       people: [Person], ownerName: String) -> [EventShare] {
        let byId = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        var out: [String: EventShare] = [:]
        var order: [String] = []

        func bump(_ id: String, _ name: String, _ color: String, _ amount: Double, _ owed: Double) {
            if var existing = out[id] {
                existing.amount = SplitMath.centavos(existing.amount + amount)
                existing.owed = SplitMath.centavos(existing.owed + owed)
                out[id] = existing
            } else {
                out[id] = EventShare(personId: id, name: name, color: color, amount: amount, owed: owed)
                order.append(id)
            }
        }

        let owner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        for row in self.transactions(transactions, eventID: eventID) where row.amount < 0 {
            bump(SplitMath.meID, owner.isEmpty ? "You" : owner, "#0b0b0c", SplitMath.spend(row), 0)
            for part in row.split?.parts ?? [] {
                let person = byId[part.personId]
                bump(part.personId, person?.name ?? part.name, person?.color ?? "#6d6d72",
                     part.amount, part.settledAt == nil ? part.amount : 0)
            }
        }

        return order.compactMap { out[$0] }.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
    }

    static func dateLabel(_ event: EventGroup) -> String {
        let started = Date(timeIntervalSince1970: event.startedAt / 1000)
            .formatted(.dateTime.day().month(.abbreviated))
        guard let endedAt = event.endedAt else { return "\(started) · still running" }
        let ended = Date(timeIntervalSince1970: endedAt / 1000)
            .formatted(.dateTime.day().month(.abbreviated))
        return started == ended ? "\(started) · closed" : "\(started) – \(ended)"
    }

    /// The plain-text summary handed to the share sheet — what gets pasted into a group chat.
    static func summaryText(event: EventGroup, totals: EventTotals, shares: [EventShare]) -> String {
        var lines = [
            "\(event.emoji) \(event.name)",
            "Total: ₱\(MoneyFormat.amount(totals.total)) across \(totals.count == 1 ? "1 spend" : "\(totals.count) spends")",
            "",
        ]
        lines += shares.map { share in
            let owed = share.owed > 0 ? " (₱\(MoneyFormat.amount(share.owed)) still to send)" : ""
            return "\(share.name): ₱\(MoneyFormat.amount(share.amount))\(owed)"
        }
        if totals.owed > 0 {
            lines += ["", "Still out: ₱\(MoneyFormat.amount(totals.owed))"]
        }
        // The summary lands in a group chat where most readers do not have the app. The link
        // is the only thing in the message that is for them rather than about the money.
        lines += ["", "Split it yourself with Pesolita — free, and nothing leaves your phone:", appStoreURL]
        return lines.joined(separator: "\n")
    }
}

/// A settlement waiting on the slide-to-confirm gesture.
struct PendingSettle: Identifiable, Equatable, Sendable {
    var personID: String
    /// Empty means "everything this person owes".
    var txID: String
    var id: String { "\(personID)|\(txID)" }
}
