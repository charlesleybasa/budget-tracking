import Foundation

/// Combines the wallet on this phone with the one in the cloud, for the "Combine both" choice.
///
/// Everything is matched by id. Ids are generated per entry, so an entry that exists on both
/// sides is the *same* entry and appears once — combining can never double a transaction. When
/// both sides hold the same id, the side saved more recently wins. Device preferences (theme,
/// name, layout) stay as they are on this phone, because this is the phone being held.
///
/// The one thing ids cannot catch is the same real card typed in twice — a "GCash" created by
/// hand on a new phone and the "GCash" in the backup are different ids. That is surfaced in
/// `MergePreview.sameNamedCards` so the user sees it before combining, rather than discovering
/// two GCash cards afterwards.
enum WalletMerge {
    static func merge(local: WalletSnapshot, cloud: WalletSnapshot, localIsNewer: Bool) -> WalletSnapshot {
        var result = local
        result.cards = union(local.cards, cloud.cards, preferLocal: localIsNewer)
        result.people = union(local.people, cloud.people, preferLocal: localIsNewer)
        result.events = union(local.events, cloud.events, preferLocal: localIsNewer)
        // Transactions carry their split parts, so a settled part travels with its transaction.
        result.tx = union(local.tx, cloud.tx, preferLocal: localIsNewer).sorted { $0.at > $1.at }
        result.dismissedNotices = Array(Set(local.dismissedNotices).union(cloud.dismissedNotices)).sorted()
        if result.userName.isEmpty { result.userName = cloud.userName }
        result.onboarded = local.onboarded || cloud.onboarded
        if !result.cards.contains(where: { $0.id == result.activeId }) {
            result.activeId = result.cards.first?.id ?? ""
        }
        result.savedAt = nil
        result.savedOn = nil
        return result
    }

    /// Keeps the order of the preferred side, then appends what only the other side has.
    private static func union<T: Identifiable>(_ local: [T], _ cloud: [T], preferLocal: Bool) -> [T] where T.ID == String {
        let (first, second) = preferLocal ? (local, cloud) : (cloud, local)
        var seen = Set(first.map(\.id))
        var out = first
        for item in second where !seen.contains(item.id) {
            out.append(item)
            seen.insert(item.id)
        }
        return out
    }
}

/// What "Combine both" would do, described before anyone commits to it.
struct MergePreview: Equatable {
    /// Cards that exist only in the backup and would be added to this phone.
    var cardsFromBackup: [String]
    /// Transactions that exist only in the backup.
    var transactionsFromBackup: Int
    /// Cards that exist only on this phone and would be added to the backup.
    var cardsFromPhone: [String]
    var transactionsFromPhone: Int
    /// Different cards with the same name on each side — probably the same real card entered
    /// twice. They will both be kept; the user should know.
    var sameNamedCards: [String]

    init(local: WalletSnapshot, cloud: WalletSnapshot) {
        let localCardIDs = Set(local.cards.map(\.id))
        let cloudCardIDs = Set(cloud.cards.map(\.id))
        let onlyCloud = cloud.cards.filter { !localCardIDs.contains($0.id) }
        let onlyLocal = local.cards.filter { !cloudCardIDs.contains($0.id) }
        cardsFromBackup = onlyCloud.map(\.nick)
        cardsFromPhone = onlyLocal.map(\.nick)

        let localTx = Set(local.tx.map(\.id))
        let cloudTx = Set(cloud.tx.map(\.id))
        transactionsFromBackup = cloud.tx.filter { !localTx.contains($0.id) }.count
        transactionsFromPhone = local.tx.filter { !cloudTx.contains($0.id) }.count

        func key(_ nick: String) -> String { nick.lowercased().trimmingCharacters(in: .whitespaces) }
        let phoneNames = Set(onlyLocal.map { key($0.nick) })
        sameNamedCards = onlyCloud.map(\.nick).filter { phoneNames.contains(key($0)) }
    }
}
