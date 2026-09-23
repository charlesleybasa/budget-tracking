import CryptoKit
import Foundation

/// The rules for keeping one wallet on this phone and one copy in the cloud honest with each
/// other — kept as pure functions so every rule is testable without a network.
///
/// The first version of sync wrote the phone's wallet over the cloud copy on every change and
/// never read it back. A reinstall followed by a sign-in overwrote years of history with an
/// almost-empty wallet, and "Start over" wiped the backup outright. The principle here is the
/// inverse: **nothing is written to the cloud until this device has read it and agreed with
/// it**, and anything that would lose data on either side is a question for the user.

/// What the cloud copy contains, for describing it before anyone commits to anything.
struct CloudSummary: Equatable, Sendable {
    var cards: Int
    var transactions: Int
    var people: Int
    var savedAt: Date?
    var savedOn: String?
    var cardNames: [String]

    init(_ snapshot: WalletSnapshot) {
        cards = snapshot.cards.count
        transactions = snapshot.tx.count
        people = snapshot.people.count
        savedAt = snapshot.savedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        savedOn = snapshot.savedOn
        cardNames = snapshot.cards.map(\.nick)
    }
}

/// Where sync is. Uploads happen only in `.live`.
enum SyncPhase: Equatable, Sendable {
    case signedOut
    /// Signed in, reading the cloud copy. Nothing is uploaded meanwhile.
    case reconciling
    /// The cloud and this phone disagree in a way only the user can settle.
    case needsDecision(SyncDecision)
    /// In step; changes upload as they happen.
    case live
    case paused(PauseReason)
}

enum PauseReason: Equatable, Sendable {
    /// Signed in, but this Apple ID does not own Pesolita Pro. Restoring is still allowed.
    case notPro
    /// The cloud could not be reached. Nothing changed on either side.
    case unreachable(String)
}

/// The outcome of comparing this phone with the cloud after signing in.
enum SyncDecision: Equatable, Sendable {
    /// No backup, nothing on this phone.
    case nothingYet
    /// No backup yet, but this phone has a wallet — it becomes the backup (Pro).
    case uploadLocal
    /// This phone is empty and a backup exists: bring it back.
    case restore(CloudSummary)
    /// Both have data and they diverged: Combine, Use backup, or Keep this phone.
    case twoWallets(CloudSummary)
    /// The cloud moved on (another device) and this phone has no changes of its own —
    /// safe to take the cloud copy without asking.
    case adoptCloud(CloudSummary)
    /// Already in step.
    case inStep
}

/// What this device last agreed with the cloud, remembered per signed-in account.
struct SyncLedger: Equatable, Sendable {
    /// The cloud copy's `savedAt` at the last agreement.
    var cloudSavedAt: Double?
    /// Fingerprint of the local wallet at the last agreement — to tell whether this phone has
    /// changed since.
    var localFingerprint: String?

    static let fresh = SyncLedger()
}

enum CloudSync {
    /// Decide what signing in (or coming back to the app) should do. Pure: same inputs, same
    /// answer, no side effects.
    static func decide(local: WalletSnapshot, cloud: WalletSnapshot?, ledger: SyncLedger) -> SyncDecision {
        let localChanged = ledger.localFingerprint != fingerprint(local)

        guard let cloud, !cloud.isEffectivelyEmpty else {
            return local.isEffectivelyEmpty ? .nothingYet : .uploadLocal
        }
        let summary = CloudSummary(cloud)

        // Same wallet on both sides (media references aside, which differ by design: `file:`
        // here, `https:` there) — nothing to ask about.
        if contentFingerprint(local) == contentFingerprint(cloud) { return .inStep }

        // A backup written by the first version of sync carries no `savedAt`. On the phone
        // that wrote it, every item in it still exists locally — uploading loses nothing, so
        // an existing Pro user is not asked about their own wallet the first time they update.
        if cloud.savedAt == nil, ledger.cloudSavedAt == nil, contains(local, everythingIn: cloud) {
            return .uploadLocal
        }

        // The cloud is exactly where we left it.
        if let known = ledger.cloudSavedAt, known == cloud.savedAt {
            return localChanged ? .uploadLocal : .inStep
        }
        // The cloud has something this phone has never agreed with — first sign-in here, or
        // another device wrote since.
        if local.isEffectivelyEmpty { return .restore(summary) }
        if ledger.cloudSavedAt != nil && !localChanged { return .adoptCloud(summary) }
        return .twoWallets(summary)
    }

    enum PushVerdict: Equatable {
        case push
        case notLive
        case notPro
        /// Would overwrite a real backup with an empty wallet — the signature of a wipe.
        case refuseEmptyOverData
        /// Someone else wrote since this device last agreed; re-decide instead of overwriting.
        case cloudMovedOn
    }

    /// Whether an upload may go ahead, given a fresh read of the cloud.
    static func verdict(phase: SyncPhase, isPro: Bool, local: WalletSnapshot,
                        cloud: WalletSnapshot?, ledger: SyncLedger) -> PushVerdict {
        guard phase == .live else { return .notLive }
        guard isPro else { return .notPro }
        if let cloud, !cloud.isEffectivelyEmpty {
            if local.isEffectivelyEmpty { return .refuseEmptyOverData }
            if cloud.savedAt != ledger.cloudSavedAt { return .cloudMovedOn }
        }
        return .push
    }

    /// Whether the orphaned-media sweep may run after an upload.
    ///
    /// The storage path inside the `media` bucket for a photo link the backup stores, so the
    /// photo can be downloaded with the user's own sign-in — which keeps working once the
    /// bucket is private. Backups hold public-style links (older versions read them directly),
    /// and signed links look the same apart from `sign` and a query string.
    static func mediaPath(fromLink link: String) -> String? {
        guard let url = URL(string: link) else { return nil }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        // …/storage/v1/object/{public|sign|authenticated}/media/<path…>
        guard let object = parts.firstIndex(of: "object"),
              parts.count > object + 3,
              ["public", "sign", "authenticated"].contains(parts[object + 1]),
              parts[object + 2] == "media" else { return nil }
        let path = parts[(object + 3)...].joined(separator: "/")
        return path.removingPercentEncoding ?? path
    }

    /// The sweep deletes cloud photos the new snapshot no longer references. After an ordinary
    /// edit that is housekeeping; after a wallet shrank by more than half it is almost always
    /// the tail end of a wipe, and deleting the photos would make it unrecoverable.
    static func mediaSweepAllowed(previous: WalletSnapshot?, next: WalletSnapshot) -> Bool {
        guard let previous else { return true }
        func halved(_ before: Int, _ after: Int) -> Bool { before >= 2 && after * 2 < before }
        return !halved(previous.cards.count, next.cards.count) && !halved(previous.tx.count, next.tx.count)
    }

    /// Whether every card, transaction, person and event in `other` also exists (by id) in
    /// `wallet` — i.e. replacing `other` with `wallet` would drop nothing.
    static func contains(_ wallet: WalletSnapshot, everythingIn other: WalletSnapshot) -> Bool {
        Set(other.cards.map(\.id)).isSubset(of: wallet.cards.map(\.id))
            && Set(other.tx.map(\.id)).isSubset(of: wallet.tx.map(\.id))
            && Set(other.people.map(\.id)).isSubset(of: wallet.people.map(\.id))
            && Set(other.events.map(\.id)).isSubset(of: wallet.events.map(\.id))
    }

    /// Like `fingerprint`, but blind to media references and display preferences, so the same
    /// wallet compares equal whether its photos live on this phone or in cloud storage.
    static func contentFingerprint(_ snapshot: WalletSnapshot) -> String {
        var copy = snapshot
        copy.userPhotoSrc = nil
        for i in copy.cards.indices {
            copy.cards[i].qr = nil
            copy.cards[i].art.photo?.src = ""
        }
        for i in copy.tx.indices { copy.tx[i].receipt = nil }
        copy.appTheme = .system
        copy.privacy = false
        copy.widgetPrivacy = false
        copy.haptics = true
        copy.sfx = true
        copy.activeId = ""
        return fingerprint(copy)
    }

    /// A stable fingerprint of the parts of a wallet that are the user's data. Cloud-only
    /// stamps are excluded so the same wallet fingerprints the same on either side.
    static func fingerprint(_ snapshot: WalletSnapshot) -> String {
        var copy = snapshot
        copy.savedAt = nil
        copy.savedOn = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(copy)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
