import Foundation
import StoreKit

@Observable
final class ProStore {
    static let productID = "com.sunpebble.simmer.lifetime"
    static let proCacheKey = "isPro"

    var isPro: Bool
    var product: Product?
    var purchaseError: String?

    init() {
        // 买断解锁状态缓存在本地:已购用户冷启动即解锁,不依赖启动时那次
        // currentEntitlements 查询(TestFlight 更新后首启经常为空)。
        // ponytail: 退款不回收缓存 —— refresh() 本就只增不减,$1.99 买断不值得防
        isPro = UserDefaults.standard.bool(forKey: Self.proCacheKey)
    }

    private func unlock() {
        isPro = true
        UserDefaults.standard.set(true, forKey: Self.proCacheKey)
    }

    var displayPrice: String { product?.displayPrice ?? "$1.99" }

    @MainActor
    func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("-pro") {
            isPro = true
            return
        }
        #endif
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                purchaseError = "Product not available. Check App Store Connect setup."
            }
        } catch {
            purchaseError = "Couldn't load product: \(error.localizedDescription)"
        }
        await refresh()
    }

    @MainActor
    func refresh() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID {
                unlock()
            }
        }
    }

    @MainActor
    func purchase() async {
        purchaseError = nil
        guard let product else {
            purchaseError = "Product not available. Check App Store Connect setup."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                unlock()
                await transaction.finish()
            case .success(.unverified(_, let error)):
                purchaseError = "Purchase couldn't be verified: \(error.localizedDescription)"
            case .pending:
                purchaseError = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    func restore() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
        await refresh()
    }

    @MainActor
    func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update,
               transaction.productID == Self.productID {
                unlock()
                await transaction.finish()
            }
        }
    }
}
