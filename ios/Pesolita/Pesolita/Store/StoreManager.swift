import Foundation
import StoreKit

/// Pesolita Pro — a one-time, non-consumable purchase.
///
/// Lives for the whole app session (it used to exist only while the Pro sheet was open, so a
/// new phone never learned it owned Pro until the user happened to open that sheet).
@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published private(set) var hasPro = UserDefaults.standard.bool(forKey: "isPro")
    @Published private(set) var isRestoring = false
    /// The App Store did not return the product — offline, or not yet live. The purchase
    /// button shows this instead of spinning forever.
    @Published private(set) var productsUnavailable = false

    let proProductID = "com.pesolita.pro"
    private var updatesTask: Task<Void, Never>?

    /// Kept for the existing call sites that read the set directly.
    var purchasedProductIDs: Set<String> { hasPro ? [proProductID] : [] }

    init() {
        updatesTask = listenForTransactions()
        Task { await refreshEntitlement() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        productsUnavailable = false
        do {
            products = try await Product.products(for: [proProductID])
            productsUnavailable = products.isEmpty
        } catch {
            productsUnavailable = true
        }
    }

    func purchase(_ product: Product) async throws {
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// "Restore Purchases" — required for a non-consumable, and the path for someone who
    /// bought Pro on another iPhone with the same Apple ID.
    /// - Returns: whether Pro is owned afterwards.
    @discardableResult
    func restorePurchases() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }
        try? await AppStore.sync()
        await refreshEntitlement()
        return hasPro
    }

    /// Re-reads what this Apple ID owns. Also clears Pro when a purchase is refunded or
    /// revoked, rather than keeping it forever once it was seen.
    func refreshEntitlement() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setPro(owned)
    }

    /// Kept for existing callers.
    func updatePurchasedStatus() async { await refreshEntitlement() }

    #if DEBUG
    /// Debug-only override used by the Pro sheet's developer toggle.
    func debugSetPro(_ value: Bool) { setPro(value) }
    #endif

    private func setPro(_ value: Bool) {
        hasPro = value
        UserDefaults.standard.set(value, forKey: "isPro")
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
