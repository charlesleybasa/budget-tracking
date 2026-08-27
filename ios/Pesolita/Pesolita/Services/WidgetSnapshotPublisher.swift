import Foundation
import WidgetKit

/// The small, stable projection of the wallet shared with the WidgetKit extension.
/// The full wallet document and imported media remain private to the app container.
struct WidgetWalletPayload: Codable, Equatable, Sendable {
    var version = 1
    var cards: [WidgetCardPayload]
    var transactions: [WidgetTransactionPayload]
    var activeCardID: String
    var totalBalance: Double
    var privacyEnabled: Bool
    var updatedAt: Double

    init(snapshot: WalletSnapshot, now: Date = .now) {
        cards = snapshot.cards.map { card in
            WidgetCardPayload(
                id: card.id,
                name: card.nick,
                kind: card.kind.rawValue,
                balance: card.bal,
                safeToday: WalletMetrics.safeToSpend(card, transactions: snapshot.tx, now: now),
                frozen: card.frozen,
                last4: card.last4,
                primaryHex: card.art.c1,
                secondaryHex: card.art.c2,
                artStyle: card.art.style.rawValue,
                templatePath: card.art.photo?.src.hasPrefix("template:") == true
                    ? String(card.art.photo!.src.dropFirst("template:".count))
                    : nil,
                useDarkText: CardTheme(art: card.art).useDarkText
            )
        }
        transactions = snapshot.tx
            .sorted { $0.at > $1.at }
            .prefix(24)
            .map {
                WidgetTransactionPayload(
                    id: $0.id,
                    cardID: $0.cardId,
                    merchant: $0.merchant,
                    category: $0.cat.rawValue,
                    amount: $0.amount,
                    timestamp: $0.at
                )
            }
        activeCardID = snapshot.activeId
        totalBalance = snapshot.cards.reduce(0) { $0 + $1.bal }
        privacyEnabled = snapshot.privacy
        updatedAt = now.timeIntervalSince1970
    }
}

struct WidgetCardPayload: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String
    var balance: Double
    var safeToday: Double
    var frozen: Bool
    var last4: String
    var primaryHex: String
    var secondaryHex: String
    var artStyle: String
    var templatePath: String?
    var useDarkText: Bool
}

struct WidgetTransactionPayload: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var cardID: String
    var merchant: String
    var category: String
    var amount: Double
    var timestamp: Double
}

enum WidgetSnapshotPublisher {
    static let appGroup = "group.com.pesolita.app"
    static let payloadKey = "pesolita.widget.wallet.v1"
    static let selectedCardKey = "pesolita.widget.selected-card"
    static let widgetKind = "PesolitaPocketWidget"

    static func publish(_ snapshot: WalletSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(WidgetWalletPayload(snapshot: snapshot)) else { return }

        defaults.set(data, forKey: payloadKey)
        let selected = defaults.string(forKey: selectedCardKey)
        if selected == nil || !snapshot.cards.contains(where: { $0.id == selected }) {
            defaults.set(snapshot.activeId, forKey: selectedCardKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
