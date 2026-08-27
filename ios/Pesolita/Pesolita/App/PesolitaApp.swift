import SwiftUI

@main
struct PesolitaApp: App {
    @State private var store = WalletStore()

    init() {
        AppFont.registerBundledFont()
        FeedbackCenter.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .task { await store.load() }
                .onOpenURL(perform: store.handleDeepLink)
        }
    }
}
