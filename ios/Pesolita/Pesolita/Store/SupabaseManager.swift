import Foundation
import Supabase
import UIKit

let supabaseURL = URL(string: "https://exapqjxrptjhvvbcnrdr.supabase.co")!
let supabaseKey = "sb_publishable_SjxUFUQakjxH4MXMrZXKQg_H6rSZjW3"

let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

/// Keeps the wallet on this phone and the Pesolita Pro backup in step.
///
/// The rules live in `CloudSync` (pure, tested). This type does the I/O and holds the phase.
/// Uploads only ever happen in `.live`, which is reached only after the cloud copy has been
/// read and this phone has agreed with it — a new sign-in, a reinstall or "Start over" can no
/// longer overwrite a backup.
@MainActor
final class SyncManager: ObservableObject {
    @Published private(set) var phase: SyncPhase = .signedOut
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    /// Set by the app from StoreKit. Restoring never needs it; ongoing backup does.
    var isPro = false {
        didSet { if isPro != oldValue { entitlementChanged() } }
    }

    /// The cloud copy as last read — what the decision screens describe and act on.
    private(set) var cloudSnapshot: WalletSnapshot?
    private var pendingPush: WalletSnapshot?
    private var pushTask: Task<Void, Never>?
    private weak var mediaStore: MediaStore?
    /// Launch, sign-in and returning to the foreground can all ask at once; one read at a time.
    private var isReconciling = false

    init() {
        Task { await checkSession() }
    }

    var email: String? { currentUser?.email }

    // MARK: - Session

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            currentUser = session.user
        } catch {
            isAuthenticated = false
            currentUser = nil
            phase = .signedOut
        }
    }

    func signInWithGoogle() async throws {
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "com.pesolita.app://login-callback")!
        )
        await checkSession()
    }

    /// Signs out on this phone. The wallet stays; backups stop.
    func signOut() async {
        pushTask?.cancel()
        pushTask = nil
        pendingPush = nil
        try? await supabase.auth.signOut()
        isAuthenticated = false
        currentUser = nil
        cloudSnapshot = nil
        phase = .signedOut
    }

    /// "Start over" erases this phone only. Sign out first so the now-empty wallet can never be
    /// uploaded over the backup — it stays in the cloud, ready to be restored.
    func prepareForReset() async {
        await signOut()
    }

    // MARK: - Reconcile

    /// Reads the cloud and decides what to do. Runs after sign-in, at launch and on return to
    /// the foreground. Anything that could lose data on either side ends in `.needsDecision`.
    func reconcile(_ store: WalletStore) async {
        guard isAuthenticated, let user = currentUser else { phase = .signedOut; return }
        mediaStore = store.mediaStore
        // A question already on screen is not re-asked underneath the user.
        if case .needsDecision = phase { return }
        guard !isReconciling else { return }
        isReconciling = true
        defer { isReconciling = false }
        phase = .reconciling
        do {
            let cloud = try await fetchCloud(userID: user.id)
            cloudSnapshot = cloud
            let decision = CloudSync.decide(local: store.snapshot, cloud: cloud, ledger: ledger(for: user.id))
            await act(on: decision, store: store, userID: user.id)
        } catch {
            phase = .paused(.unreachable(error.localizedDescription))
        }
    }

    private func act(on decision: SyncDecision, store: WalletStore, userID: UUID) async {
        switch decision {
        case .inStep:
            saveLedger(SyncLedger(cloudSavedAt: cloudSnapshot?.savedAt,
                                  localFingerprint: CloudSync.fingerprint(store.snapshot)), for: userID)
            phase = isPro ? .live : .paused(.notPro)
        case .uploadLocal:
            // Nothing in the cloud would be lost. Uploading is a Pro feature.
            saveLedger(SyncLedger(cloudSavedAt: cloudSnapshot?.savedAt, localFingerprint: nil), for: userID)
            if isPro {
                phase = .live
                schedule(store.snapshot)
            } else {
                phase = .paused(.notPro)
            }
        case .adoptCloud:
            // Another device moved on and this phone changed nothing: take it quietly.
            await useBackup(store)
            store.showToast("Updated from your other device.")
        case .nothingYet, .restore, .twoWallets:
            phase = .needsDecision(decision)
        }
    }

    // MARK: - Choices (from the restore flow)

    /// Replace this phone's wallet with the backup. Free — it is the user's own data.
    func useBackup(_ store: WalletStore) async {
        guard let user = currentUser, let cloud = cloudSnapshot else { return }
        let local = await bringMediaHome(cloud)
        store.apply(local)
        saveLedger(SyncLedger(cloudSavedAt: cloud.savedAt,
                              localFingerprint: CloudSync.fingerprint(store.snapshot)), for: user.id)
        phase = isPro ? .live : .paused(.notPro)
    }

    /// Keep everything from both sides. The combined wallet then becomes the backup (Pro).
    func combine(_ store: WalletStore) async {
        guard let user = currentUser, let cloud = cloudSnapshot else { return }
        let localIsNewer = (cloud.savedAt ?? 0) < Date().timeIntervalSince1970 * 1000
        let merged = WalletMerge.merge(local: store.snapshot, cloud: await bringMediaHome(cloud),
                                       localIsNewer: localIsNewer)
        store.apply(merged)
        // Marked dirty on purpose: the backup is missing this phone's half until uploaded.
        saveLedger(SyncLedger(cloudSavedAt: cloud.savedAt, localFingerprint: nil), for: user.id)
        phase = isPro ? .live : .paused(.notPro)
        if isPro { schedule(store.snapshot) }
    }

    /// Keep this phone's wallet and make it the backup, replacing what was in the cloud.
    func keepThisPhone(_ store: WalletStore) async {
        guard let user = currentUser else { return }
        saveLedger(SyncLedger(cloudSavedAt: cloudSnapshot?.savedAt, localFingerprint: nil), for: user.id)
        phase = isPro ? .live : .paused(.notPro)
        if isPro { schedule(store.snapshot) }
    }

    /// Nothing to restore and nothing to protect: start clean and back up from here.
    func startFresh() {
        phase = isPro ? .live : .paused(.notPro)
    }

    // MARK: - Upload

    /// Queues the latest wallet for upload. Rapid edits collapse into one upload, and uploads
    /// never overlap — overlapping ones could finish out of order and leave the older wallet in
    /// the cloud.
    func schedule(_ snapshot: WalletSnapshot, mediaStore store: MediaStore? = nil) {
        if let store { mediaStore = store }
        guard phase == .live, isPro, let user = currentUser else { return }
        // Nothing changed since the last agreement — no upload.
        if ledger(for: user.id).localFingerprint == CloudSync.fingerprint(snapshot) { return }
        pendingPush = snapshot
        guard pushTask == nil else { return }
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            while let self, let next = self.pendingPush {
                self.pendingPush = nil
                await self.upload(next, userID: user.id)
            }
            self?.pushTask = nil
        }
    }

    private func upload(_ local: WalletSnapshot, userID: UUID) async {
        guard let mediaStore else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            // Always read before writing.
            let cloud = try await fetchCloud(userID: userID)
            let ledger = ledger(for: userID)
            switch CloudSync.verdict(phase: phase, isPro: isPro, local: local, cloud: cloud, ledger: ledger) {
            case .push:
                break
            case .notLive:
                return
            case .notPro:
                phase = .paused(.notPro)
                return
            case .refuseEmptyOverData:
                // An empty wallet never replaces a real backup.
                return
            case .cloudMovedOn:
                // Another device wrote since we last agreed. Ask, rather than overwrite it.
                cloudSnapshot = cloud
                phase = .needsDecision(CloudSync.decide(local: local, cloud: cloud, ledger: ledger))
                return
            }

            var remote = local
            for i in remote.cards.indices {
                if let src = remote.cards[i].art.photo?.src, src.hasPrefix("file:"),
                   let url = try await uploadMedia(src, mediaStore: mediaStore, userID: userID) {
                    remote.cards[i].art.photo?.src = url
                }
                if let qr = remote.cards[i].qr, qr.hasPrefix("file:"),
                   let url = try await uploadMedia(qr, mediaStore: mediaStore, userID: userID) {
                    remote.cards[i].qr = url
                }
            }
            for i in remote.tx.indices {
                if let receipt = remote.tx[i].receipt, receipt.hasPrefix("file:"),
                   let url = try await uploadMedia(receipt, mediaStore: mediaStore, userID: userID) {
                    remote.tx[i].receipt = url
                }
            }
            remote.savedAt = (Date().timeIntervalSince1970 * 1000).rounded()
            remote.savedOn = UIDevice.current.name

            struct Row: Encodable { let user_id: UUID; let data: WalletSnapshot }
            try await supabase.from("snapshots").upsert(Row(user_id: userID, data: remote), onConflict: "user_id").execute()

            saveLedger(SyncLedger(cloudSavedAt: remote.savedAt, localFingerprint: CloudSync.fingerprint(local)), for: userID)
            cloudSnapshot = remote
            lastSyncTime = Date()

            if CloudSync.mediaSweepAllowed(previous: cloud, next: remote) {
                await sweepOrphanedMedia(keeping: remote, userID: userID)
            }
        } catch {
            phase = .paused(.unreachable(error.localizedDescription))
        }
    }

    /// Retry after the cloud was unreachable.
    func retry(_ store: WalletStore) async {
        phase = isAuthenticated ? .reconciling : .signedOut
        await reconcile(store)
    }

    private func entitlementChanged() {
        switch phase {
        case .live where !isPro: phase = .paused(.notPro)
        case .paused(.notPro) where isPro: phase = .live
        default: break
        }
    }

    // MARK: - Cloud I/O

    private func fetchCloud(userID: UUID) async throws -> WalletSnapshot? {
        struct Row: Decodable { let data: WalletSnapshot }
        let rows: [Row] = try await supabase.from("snapshots")
            .select("data")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first?.data
    }

    private func uploadMedia(_ reference: String, mediaStore: MediaStore, userID: UUID) async throws -> String? {
        guard let data = try await mediaStore.data(for: reference) else { return nil }
        let path = "\(userID.uuidString)/\(reference).jpg"
        _ = try await supabase.storage.from("media").upload(
            path: path,
            file: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        )
        return try supabase.storage.from("media").getPublicURL(path: path).absoluteString
    }

    private func sweepOrphanedMedia(keeping remote: WalletSnapshot, userID: UUID) async {
        var active = Set<String>()
        for card in remote.cards {
            if let src = card.art.photo?.src, src.hasPrefix("http") { active.insert(URL(string: src)?.lastPathComponent ?? "") }
            if let qr = card.qr, qr.hasPrefix("http") { active.insert(URL(string: qr)?.lastPathComponent ?? "") }
        }
        for tx in remote.tx {
            if let receipt = tx.receipt, receipt.hasPrefix("http") { active.insert(URL(string: receipt)?.lastPathComponent ?? "") }
        }
        guard let files = try? await supabase.storage.from("media").list(path: userID.uuidString) else { return }
        let stale = files
            .filter { $0.name != ".emptyFolderPlaceholder" && !active.contains($0.name) }
            .map { "\(userID.uuidString)/\($0.name)" }
        if !stale.isEmpty { _ = try? await supabase.storage.from("media").remove(paths: stale) }
    }

    /// Pesolita works offline, so a restored wallet should too: bring backed-up photos, QR codes
    /// and receipts onto the phone. Anything that fails to download keeps its web address and
    /// still shows while online.
    private func bringMediaHome(_ cloud: WalletSnapshot) async -> WalletSnapshot {
        guard let mediaStore else { return cloud }
        var copy = cloud
        func localise(_ reference: String?) async -> String? {
            guard let reference, reference.hasPrefix("http"),
                  let data = await downloadMedia(reference),
                  let stored = try? await mediaStore.write(data) else { return reference }
            return stored
        }
        for i in copy.cards.indices {
            if let src = copy.cards[i].art.photo?.src, let home = await localise(src) { copy.cards[i].art.photo?.src = home }
            copy.cards[i].qr = await localise(copy.cards[i].qr)
        }
        for i in copy.tx.indices { copy.tx[i].receipt = await localise(copy.tx[i].receipt) }
        copy.savedAt = nil
        copy.savedOn = nil
        return copy
    }

    /// Downloads a backed-up photo. Uses the user's sign-in first, so it keeps working after
    /// the `media` bucket is made private; falls back to the plain link for anything else.
    private func downloadMedia(_ link: String) async -> Data? {
        if let path = CloudSync.mediaPath(fromLink: link),
           let data = try? await supabase.storage.from("media").download(path: path) {
            return data
        }
        guard let url = URL(string: link),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    // MARK: - Delete account

    enum DeleteOutcome {
        /// Backup, photos and the sign-in account are gone.
        case everythingDeleted
        /// Backup and photos are gone, but the server could not remove the sign-in account
        /// (its delete function is not installed yet). Signing in again would start empty.
        case dataDeletedAccountRemains
    }

    /// "Delete backup & account": removes the cloud photos, the wallet backup and the sign-in
    /// account, then signs out. The wallet on this iPhone is not touched, and Pesolita Pro stays
    /// with the Apple ID — it was bought from Apple, not from this account.
    func deleteAccount() async throws -> DeleteOutcome {
        guard let user = currentUser else { throw DeleteError.notSignedIn }
        pushTask?.cancel()
        pushTask = nil
        pendingPush = nil
        // Stop anything else writing while this runs.
        phase = .reconciling

        do {
            // Photos first: the account's folder is the only way to find them.
            let folder = user.id.uuidString
            let files = try await supabase.storage.from("media").list(path: folder)
            let paths = files.filter { $0.name != ".emptyFolderPlaceholder" }.map { "\(folder)/\($0.name)" }
            if !paths.isEmpty { _ = try await supabase.storage.from("media").remove(paths: paths) }

            // Deleting the row directly as well means the backup is gone even if the server
            // function below is missing.
            try await supabase.from("snapshots").delete().eq("user_id", value: user.id).execute()
        } catch {
            phase = .paused(.unreachable(error.localizedDescription))
            throw error
        }

        var outcome = DeleteOutcome.everythingDeleted
        do {
            try await supabase.rpc("delete_my_account").execute()
        } catch {
            outcome = .dataDeletedAccountRemains
        }

        let key = "sync.ledger.\(user.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key + ".cloudSavedAt")
        UserDefaults.standard.removeObject(forKey: key + ".localFingerprint")
        await signOut()
        return outcome
    }

    enum DeleteError: LocalizedError {
        case notSignedIn
        var errorDescription: String? { "Sign in with Google first." }
    }

    // MARK: - Ledger

    private func ledger(for userID: UUID) -> SyncLedger {
        let defaults = UserDefaults.standard
        let key = "sync.ledger.\(userID.uuidString)"
        return SyncLedger(
            cloudSavedAt: defaults.object(forKey: key + ".cloudSavedAt") as? Double,
            localFingerprint: defaults.string(forKey: key + ".localFingerprint")
        )
    }

    private func saveLedger(_ ledger: SyncLedger, for userID: UUID) {
        let defaults = UserDefaults.standard
        let key = "sync.ledger.\(userID.uuidString)"
        defaults.set(ledger.cloudSavedAt, forKey: key + ".cloudSavedAt")
        defaults.set(ledger.localFingerprint, forKey: key + ".localFingerprint")
    }
}
