import Foundation
import Testing
@testable import Pesolita

/// The data-loss paths the first version of sync shipped with, each as a test that fails if
/// it can happen again.
@Suite
struct SyncGuardTests {
    private func card(_ id: String, _ nick: String = "Card") -> Card {
        Card(id: id, kind: .debit, nick: nick, last4: "", exp: "—", bal: 100, limit: 0, art: .cash, frozen: false)
    }

    private func tx(_ id: String, card: String) -> Transaction {
        Transaction(id: id, cardId: card, merchant: "Shop", cat: .food, amount: -50, at: 1, note: "")
    }

    private func wallet(cards: [String], tx txIDs: [String] = [], savedAt: Double? = nil) -> WalletSnapshot {
        var w = WalletSnapshot()
        w.cards = cards.map { card($0) }
        w.tx = txIDs.map { tx($0, card: cards[0]) }
        w.savedAt = savedAt
        return w
    }

    // MARK: Signing in

    @Test func freshInstallWithBackupOffersRestoreNeverUpload() {
        let decision = CloudSync.decide(local: .empty, cloud: wallet(cards: ["a", "b"], savedAt: 10), ledger: .fresh)
        guard case .restore(let summary) = decision else { Issue.record("got \(decision)"); return }
        #expect(summary.cards == 2)
    }

    /// The user's scenario: a wallet typed in by hand on a new phone, then signing in with an
    /// old backup. Neither side may silently win.
    @Test func handMadeWalletPlusOldBackupAsksTheUser() {
        let local = wallet(cards: ["new"])
        let cloud = wallet(cards: ["old1", "old2"], savedAt: 10)
        guard case .twoWallets = CloudSync.decide(local: local, cloud: cloud, ledger: .fresh) else {
            Issue.record("expected twoWallets"); return
        }
    }

    @Test func noBackupYetUploadsThisPhone() {
        #expect(CloudSync.decide(local: wallet(cards: ["a"]), cloud: nil, ledger: .fresh) == .uploadLocal)
        #expect(CloudSync.decide(local: .empty, cloud: nil, ledger: .fresh) == .nothingYet)
    }

    /// Existing Pro users' backups were written without `savedAt`. The phone that wrote one must
    /// not be asked about its own wallet on first launch after updating.
    @Test func legacyBackupFromThisPhoneIsNotQuestioned() {
        let local = wallet(cards: ["a", "b", "c"], tx: ["t1", "t2"])
        let cloud = wallet(cards: ["a", "b"], tx: ["t1"], savedAt: nil)
        #expect(CloudSync.decide(local: local, cloud: cloud, ledger: .fresh) == .uploadLocal)
    }

    @Test func identicalWalletsAreInStep() {
        let same = wallet(cards: ["a"], tx: ["t1"])
        var cloud = same
        cloud.savedAt = 99
        #expect(CloudSync.decide(local: same, cloud: cloud, ledger: .fresh) == .inStep)
    }

    @Test func anotherDeviceWroteAndThisPhoneDidNotChangeAdoptsQuietly() {
        let local = wallet(cards: ["a"])
        let ledger = SyncLedger(cloudSavedAt: 10, localFingerprint: CloudSync.fingerprint(local))
        let cloud = wallet(cards: ["a", "b"], savedAt: 20)
        guard case .adoptCloud = CloudSync.decide(local: local, cloud: cloud, ledger: ledger) else {
            Issue.record("expected adoptCloud"); return
        }
    }

    @Test func bothSidesChangedAsks() {
        let before = wallet(cards: ["a"])
        let ledger = SyncLedger(cloudSavedAt: 10, localFingerprint: CloudSync.fingerprint(before))
        let local = wallet(cards: ["a", "phoneOnly"])
        let cloud = wallet(cards: ["a", "otherDevice"], savedAt: 20)
        guard case .twoWallets = CloudSync.decide(local: local, cloud: cloud, ledger: ledger) else {
            Issue.record("expected twoWallets"); return
        }
    }

    // MARK: Uploading

    @Test func nothingUploadsBeforeReconciling() {
        for phase in [SyncPhase.signedOut, .reconciling, .needsDecision(.nothingYet), .paused(.notPro)] {
            #expect(CloudSync.verdict(phase: phase, isPro: true, local: wallet(cards: ["a"]), cloud: nil, ledger: .fresh) == .notLive)
        }
    }

    /// "Start over" used to push an empty wallet over the backup.
    @Test func emptyWalletNeverOverwritesABackup() {
        let cloud = wallet(cards: ["a"], savedAt: 10)
        let verdict = CloudSync.verdict(phase: .live, isPro: true, local: .empty, cloud: cloud,
                                        ledger: SyncLedger(cloudSavedAt: 10, localFingerprint: nil))
        #expect(verdict == .refuseEmptyOverData)
    }

    @Test func cloudChangedElsewhereStopsTheUpload() {
        let verdict = CloudSync.verdict(phase: .live, isPro: true, local: wallet(cards: ["a"]),
                                        cloud: wallet(cards: ["a", "b"], savedAt: 20),
                                        ledger: SyncLedger(cloudSavedAt: 10, localFingerprint: nil))
        #expect(verdict == .cloudMovedOn)
    }

    @Test func uploadingNeedsPro() {
        #expect(CloudSync.verdict(phase: .live, isPro: false, local: wallet(cards: ["a"]), cloud: nil, ledger: .fresh) == .notPro)
    }

    @Test func ordinaryEditUploads() {
        let verdict = CloudSync.verdict(phase: .live, isPro: true, local: wallet(cards: ["a", "b"]),
                                        cloud: wallet(cards: ["a"], savedAt: 10),
                                        ledger: SyncLedger(cloudSavedAt: 10, localFingerprint: nil))
        #expect(verdict == .push)
    }

    // MARK: Media

    @Test func mediaSweepSkippedWhenTheWalletCollapsed() {
        let before = wallet(cards: ["a", "b", "c", "d"], tx: ["1", "2", "3", "4"])
        #expect(!CloudSync.mediaSweepAllowed(previous: before, next: wallet(cards: ["a"], tx: ["1"])))
        #expect(CloudSync.mediaSweepAllowed(previous: before, next: wallet(cards: ["a", "b", "c"], tx: ["1", "2", "3"])))
    }

    /// Backups store public-style photo links; the app downloads them by storage path so a
    /// private bucket keeps working.
    @Test func photoLinksResolveToTheirStoragePath() {
        let base = "https://exapqjxrptjhvvbcnrdr.supabase.co/storage/v1/object"
        #expect(CloudSync.mediaPath(fromLink: "\(base)/public/media/ABC-123/file:9F2.jpg") == "ABC-123/file:9F2.jpg")
        #expect(CloudSync.mediaPath(fromLink: "\(base)/sign/media/ABC/r.jpg?token=x") == "ABC/r.jpg")
        #expect(CloudSync.mediaPath(fromLink: "\(base)/public/other/ABC/r.jpg") == nil)
        #expect(CloudSync.mediaPath(fromLink: "https://example.com/photo.jpg") == nil)
    }

    @Test func fingerprintIgnoresCloudStamps() {
        var a = wallet(cards: ["a"])
        let b = a
        a.savedAt = 123
        a.savedOn = "iPhone"
        #expect(CloudSync.fingerprint(a) == CloudSync.fingerprint(b))
    }
}
