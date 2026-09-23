import SwiftUI

@main
struct PesolitaApp: App {
    @State private var store = WalletStore()
    @StateObject private var syncManager = SyncManager()
    @StateObject private var storeManager = StoreManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppFont.registerBundledFont()
        FeedbackCenter.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environmentObject(syncManager)
                .environmentObject(storeManager)
                .task {
                    await store.load()
                    applyEntitlement(storeManager.hasPro)
                    await syncManager.checkSession()
                    await syncManager.reconcile(store)
                }
                .onOpenURL { url in
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                            // The sign-in finished outside the app; bring sync up to date.
                            await syncManager.checkSession()
                        } catch {
                            store.handleDeepLink(url)
                        }
                    }
                }
                .onChange(of: storeManager.hasPro) { _, owned in applyEntitlement(owned) }
                .onChange(of: syncManager.isAuthenticated) { _, signedIn in
                    // Signing in never uploads straight away: read the cloud and decide first.
                    if signedIn { Task { await syncManager.reconcile(store) } }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Coming back may mean another device wrote in the meantime.
                    if phase == .active, syncManager.isAuthenticated {
                        Task { await syncManager.reconcile(store) }
                    }
                }
                .onChange(of: store.snapshot) { _, newSnapshot in
                    syncManager.schedule(newSnapshot, mediaStore: store.mediaStore)
                }
        }
    }

    private func applyEntitlement(_ owned: Bool) {
        store.isPro = owned
        syncManager.isPro = owned
    }
}
