import SwiftUI

@main
struct PesolitaApp: App {
    @UIApplicationDelegateAdaptor(PesolitaAppDelegate.self) private var appDelegate
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


/// Landscape only where it earns its place: the iPhone Duo unfolded (or any window at least
/// 600 pt on its short side). Every other iPhone — and the Duo folded — stays portrait, as the
/// app always has.
final class PesolitaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let bounds = window?.windowScene?.screen.bounds else { return .portrait }
        return min(bounds.width, bounds.height) >= 600 ? .allButUpsideDown : .portrait
    }

    /// Folding or unfolding changes which orientations are allowed; ask UIKit to check again so
    /// the folded screen snaps back to portrait.
    @MainActor
    static func refreshSupportedOrientations() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}
