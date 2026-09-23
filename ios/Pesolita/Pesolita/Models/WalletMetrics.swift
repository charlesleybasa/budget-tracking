import Foundation

struct CategoryTotal: Identifiable, Sendable {
    var category: CategoryName
    var amount: Double
    var id: String { category.id }
}

struct TransactionDayGroup: Identifiable, Sendable {
    var day: Date
    var transactions: [Transaction]
    var id: Date { day }
    var total: Double { transactions.reduce(0) { $0 + abs($1.amount) } }
}

struct PeriodInsight: Sendable {
    var head: String
    var body: String
}

enum WalletMetrics {
    /// Money out of a card this calendar month. Counts the owner's share of a split spend,
    /// not the whole bill — see `SplitMath.spend`.
    static func spentThisMonth(cardID: String, transactions: [Transaction], now: Date = .now) -> Double {
        let calendar = Calendar.current
        return transactions.filter {
            $0.cardId == cardID &&
            calendar.isDate(Date(timeIntervalSince1970: $0.at / 1000), equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + SplitMath.spend($1) }
    }

    static func cardProgress(_ card: Card, transactions: [Transaction]) -> Double {
        if let goal = card.goal, goal > 0 { return min(1, max(0, card.bal / goal)) }
        let ceiling = card.limit > 0 ? card.limit : card.bal
        guard ceiling > 0 else { return 0 }
        return min(1, spentThisMonth(cardID: card.id, transactions: transactions) / ceiling)
    }

    static func safeToSpend(_ card: Card, transactions: [Transaction], now: Date = .now) -> Double {
        let ceiling = card.limit > 0 ? card.limit : card.bal
        let left = max(0, ceiling - spentThisMonth(cardID: card.id, transactions: transactions, now: now))
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 1
        let today = calendar.component(.day, from: now)
        return max(0, min(card.bal, left / Double(max(1, days - today + 1))))
    }

    static func dayGroups(_ transactions: [Transaction], cardID: String? = nil) -> [TransactionDayGroup] {
        let calendar = Calendar.current
        let filtered = transactions.filter { cardID == nil || $0.cardId == cardID }
        let grouped = Dictionary(grouping: filtered) {
            calendar.startOfDay(for: Date(timeIntervalSince1970: $0.at / 1000))
        }
        return grouped.keys.sorted(by: >).map {
            TransactionDayGroup(day: $0, transactions: grouped[$0, default: []].sorted { $0.at > $1.at })
        }
    }

    static func categoryTotals(_ transactions: [Transaction], period: InsightPeriod, now: Date = .now) -> [CategoryTotal] {
        let start = period.days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: now) }
        return CategoryName.allCases.compactMap { category in
            let total = transactions.filter {
                $0.cat == category && (start == nil || Date(timeIntervalSince1970: $0.at / 1000) >= start!)
            }.reduce(0) { $0 + SplitMath.spend($1) }
            return total > 0 ? CategoryTotal(category: category, amount: total) : nil
        }.sorted { $0.amount > $1.amount }
    }

    static func transactions(_ transactions: [Transaction], period: InsightPeriod, now: Date = .now) -> [Transaction] {
        guard let days = period.days, let start = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return transactions }
        return transactions.filter { Date(timeIntervalSince1970: $0.at / 1000) >= start }
    }

    static func insight(_ transactions: [Transaction], period: InsightPeriod) -> PeriodInsight {
        let rows = self.transactions(transactions, period: period).filter { SplitMath.spend($0) > 0 }
        guard !rows.isEmpty else {
            return PeriodInsight(head: "A clean slate.", body: "Log what leaves your pockets and Pesolita will turn it into a useful read.")
        }
        let total = rows.reduce(0) { $0 + SplitMath.spend($1) }
        let top = categoryTotals(transactions, period: period).first
        if let top {
            let share = Int((top.amount / max(1, total) * 100).rounded())
            return PeriodInsight(
                head: "\(top.category.rawValue) took the lead.",
                body: "You logged ₱\(MoneyFormat.amount(total)) out. \(top.category.rawValue) made up \(share)% of it."
            )
        }
        return PeriodInsight(head: "Money moved in.", body: "No spending in this period yet—only money coming into your pockets.")
    }

    static func search(_ transactions: [Transaction], query: String, filter: SearchFilter) -> [Transaction] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return transactions.filter { transaction in
            let matchesText = needle.isEmpty || transaction.merchant.lowercased().contains(needle) ||
                transaction.note.lowercased().contains(needle) || transaction.cat.rawValue.lowercased().contains(needle)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .moneyIn: matchesFilter = transaction.amount > 0
            case .moneyOut: matchesFilter = transaction.amount < 0
            case .split: matchesFilter = transaction.split != nil
            default: matchesFilter = filter.category == transaction.cat
            }
            return matchesText && matchesFilter
        }.sorted { $0.at > $1.at }
    }

    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// `Amount` is the whole bill, because that is what left the card; `Your share` is what it
    /// actually cost, so a split row does not overstate spending inside a pivot table.
    static func csv(transactions: [Transaction], cards: [Card], events: [EventGroup] = []) -> String {
        let names = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.nick) })
        let eventNames = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0.name) })
        let header = "Date,Card,Merchant,Category,Amount,Your share,Split with,Owed back,Event,Note"
        let rows = transactions.map { transaction in
            let date = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: transaction.at / 1000))
            let parts = transaction.split?.parts ?? []
            let owed = parts.filter { $0.settledAt == nil }.reduce(0) { $0 + $1.amount }
            let share = transaction.amount < 0 ? -SplitMath.spend(transaction) : transaction.amount
            return [date, names[transaction.cardId] ?? "Deleted card", transaction.merchant, transaction.cat.rawValue,
                    String(format: "%.2f", transaction.amount),
                    String(format: "%.2f", share),
                    parts.map(\.name).joined(separator: " · "),
                    String(format: "%.2f", owed),
                    transaction.eventId.flatMap { eventNames[$0] } ?? "",
                    transaction.note]
                .map(csvCell).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func csvCell(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
