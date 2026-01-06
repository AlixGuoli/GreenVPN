//
//  GVPurchaseManager.swift
//  GreenVPN
//
//  内购管理器：负责产品加载、购买、恢复购买、订阅状态管理
//

import Foundation
import StoreKit
import Combine

/// 内购管理器（单例）
final class GVPurchaseManager: ObservableObject {
    
    static let shared = GVPurchaseManager()
    
    // 本地缓存键（测试服：用于快速还原 VIP 状态，上线前可视情况精简）
    private let vipFlagKey = "GVPurchaseManager_VIP_Flag"
    private let vipExpirationKey = "GVPurchaseManager_VIP_Expiration"
    private let vipProductIdKey = "GVPurchaseManager_VIP_ProductId"
    
    /// 产品 ID 列表
    private let productIdentifiers: Set<String> = [
        "com.green.fire.vpn.birds.weekly",
        "com.green.fire.vpn.birds.monthly",
        "com.green.fire.vpn.birds.annual"
    ]
    
    /// 已加载的产品列表
    @Published var products: [Product] = []
    
    /// 是否正在加载产品
    @Published var isLoadingProducts: Bool = false
    /// 是否正在购买
    @Published var isPurchasing: Bool = false
    /// 是否正在恢复购买
    @Published var isRestoring: Bool = false
    
    /// 是否为 VIP（有有效订阅）
    @Published var isVIP: Bool = false
    
    /// 订阅过期时间
    @Published var expirationDate: Date? = nil
    
    /// 当前订阅的产品 ID
    @Published var currentProductId: String? = nil
    
    private init() {
        // 启动时先尝试从本地缓存还原 VIP 状态（测试服：加速首屏判断，上线仍可保留）
        restoreCachedSubscriptionState()
        
        // 启动时检查订阅状态并开始监听交易更新，防止遗漏后台完成的交易
        Task { [weak self] in
            guard let self = self else { return }
            await self.checkSubscriptionStatus()
            await self.listenForTransactionUpdates()
        }
    }
    
    // MARK: - 产品加载
    
    /// 加载产品列表
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        
        await MainActor.run {
            isLoadingProducts = true
        }
        
        do {
            let loadedProducts = try await Product.products(for: productIdentifiers)
            await MainActor.run {
                self.products = loadedProducts
                self.isLoadingProducts = false
                GVLogger.log("PurchaseManager", "✅ 加载产品成功，数量：\(loadedProducts.count)")
                
                // 打印每个产品的详细信息
                for product in loadedProducts {
                    GVLogger.log("PurchaseManager", "产品：\(product.id)")
                    GVLogger.log("PurchaseManager", "  名称：\(product.displayName)")
                    GVLogger.log("PurchaseManager", "  价格：\(product.displayPrice)")
                    GVLogger.log("PurchaseManager", "  描述：\(product.description)")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingProducts = false
            }
            GVLogger.log("PurchaseManager", "❌ 加载产品失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 购买
    
    /// 购买产品
    func purchase(_ product: Product) async throws -> Bool {
        await MainActor.run {
            isPurchasing = true
        }
        
        defer {
            Task { @MainActor in
                isPurchasing = false
            }
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证交易
                let transaction = try checkVerified(verification)
                
                // 打印交易详细信息
                GVLogger.log("PurchaseManager", "交易详情：")
                GVLogger.log("PurchaseManager", "  产品ID：\(transaction.productID)")
                GVLogger.log("PurchaseManager", "  交易ID：\(transaction.id)")
                GVLogger.log("PurchaseManager", "  购买时间：\(transaction.purchaseDate)")
                if let expiration = transaction.expirationDate {
                    GVLogger.log("PurchaseManager", "  过期时间：\(expiration)")
                } else {
                    GVLogger.log("PurchaseManager", "  过期时间：无（非消耗型产品）")
                }
                
                // 完成交易（让 StoreKit 自己处理续期逻辑）
                await transaction.finish()
                
                // 更新订阅状态
                await updateSubscriptionStatus()
                
                // 验证购买是否真的生效
                // 如果是升级场景，返回的交易可能是旧订阅的，但购买的产品ID应该匹配
                // 所以先检查返回的交易的产品ID是否匹配购买的产品ID
                if transaction.productID == product.id {
                    GVLogger.log("PurchaseManager", "✅ 购买成功：\(product.id)（交易产品ID匹配）")
                    return true
                }
                
                // 如果交易产品ID不匹配，检查当前订阅状态（可能是升级场景，新交易还没立即生效）
                let currentProductId = await MainActor.run { self.currentProductId }
                if currentProductId == product.id {
                    GVLogger.log("PurchaseManager", "✅ 购买成功：\(product.id)（订阅状态已更新）")
                    return true
                } else {
                    GVLogger.log("PurchaseManager", "⚠️ 警告：交易产品ID不匹配（\(transaction.productID) vs \(product.id)），且订阅状态未更新")
                    GVLogger.log("PurchaseManager", "⚠️ 这可能是升级场景，新交易可能需要时间生效，先返回成功")
                    // 升级场景可能需要时间，先返回成功让 UI 更新
                    return true
                }
                
            case .userCancelled:
                GVLogger.log("PurchaseManager", "用户取消购买")
                return false
                
            case .pending:
                GVLogger.log("PurchaseManager", "购买待处理")
                return false
                
            @unknown default:
                GVLogger.log("PurchaseManager", "未知购买结果")
                return false
            }
        } catch {
            GVLogger.log("PurchaseManager", "❌ 购买失败：\(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - 恢复购买
    
    /// 恢复购买
    func restorePurchases() async -> RestoreResult {
        GVLogger.log("PurchaseManager", "开始恢复购买")
        
        await MainActor.run {
            isRestoring = true
        }
        
        defer {
            Task { @MainActor in
                self.isRestoring = false
            }
        }
        
        var foundValidSubscription = false
        var firstError: Error?
        
        // 遍历所有当前有效的订阅
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 检查是否是我们支持的产品
                if productIdentifiers.contains(transaction.productID) {
                    GVLogger.log("PurchaseManager", "✅ 找到有效订阅：\(transaction.productID)")
                    foundValidSubscription = true
                }
            } catch {
                GVLogger.log("PurchaseManager", "❌ 验证交易失败：\(error.localizedDescription)")
                if firstError == nil {
                    firstError = error
                }
            }
        }
        
        // 更新订阅状态
        await updateSubscriptionStatus()
        
        if let error = firstError {
            return .failed(error)
        }
        
        if foundValidSubscription {
            return .restored
        } else {
            return .none
        }
    }
    
    // MARK: - 订阅状态检查
    
    /// 检查订阅状态
    func checkSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    /// 更新订阅状态（从当前有效的订阅中获取）
    private func updateSubscriptionStatus() async {
        var latestExpirationDate: Date? = nil
        var latestProductId: String? = nil
        
        GVLogger.log("PurchaseManager", "开始检查订阅状态...")
        var foundCount = 0
        
        // 遍历所有当前有效的订阅
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                foundCount += 1
                
                GVLogger.log("PurchaseManager", "找到交易 #\(foundCount)：\(transaction.productID)")
                GVLogger.log("PurchaseManager", "  交易ID：\(transaction.id)")
                GVLogger.log("PurchaseManager", "  购买时间：\(transaction.purchaseDate)")
                
                // 检查是否是我们支持的产品
                guard productIdentifiers.contains(transaction.productID) else {
                    GVLogger.log("PurchaseManager", "  跳过：不是我们的产品")
                    continue
                }
                
                // 获取订阅过期时间
                if let expirationDate = transaction.expirationDate {
                    GVLogger.log("PurchaseManager", "  过期时间：\(expirationDate)")
                    // 如果这个订阅过期时间更晚，更新
                    if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                        latestExpirationDate = expirationDate
                        latestProductId = transaction.productID
                        GVLogger.log("PurchaseManager", "  更新为最新订阅：\(transaction.productID)")
                    }
                } else {
                    // 非消耗型产品（没有过期时间）
                    latestExpirationDate = Date.distantFuture
                    latestProductId = transaction.productID
                    GVLogger.log("PurchaseManager", "  非消耗型产品，设置为永久")
                }
            } catch {
                GVLogger.log("PurchaseManager", "❌ 验证交易失败：\(error.localizedDescription)")
            }
        }
        
        GVLogger.log("PurchaseManager", "检查完成，共找到 \(foundCount) 个交易")
        
        // 更新状态并写入本地缓存
        await MainActor.run {
            let defaults = UserDefaults.standard
            
            if let expiration = latestExpirationDate {
                let now = Date()
                GVLogger.log("PurchaseManager", "当前选中订阅：productID=\(latestProductId ?? "nil")，过期时间=\(expiration)，是否过期=\(expiration <= now ? "是" : "否")")
                
                // 检查是否过期
                if expiration > now {
                    self.isVIP = true
                    self.expirationDate = expiration
                    self.currentProductId = latestProductId
                    GVLogger.log("PurchaseManager", "✅ VIP 状态：有效，过期时间：\(expiration)")
                    
                    // 写入本地缓存（测试服：加速启动判断）
                    defaults.set(true, forKey: vipFlagKey)
                    defaults.set(expiration.timeIntervalSince1970, forKey: vipExpirationKey)
                    defaults.set(latestProductId, forKey: vipProductIdKey)
                } else {
                    self.isVIP = false
                    self.expirationDate = nil
                    self.currentProductId = nil
                    GVLogger.log("PurchaseManager", "❌ VIP 状态：已过期")
                    
                    // 清理缓存
                    defaults.set(false, forKey: vipFlagKey)
                    defaults.removeObject(forKey: vipExpirationKey)
                    defaults.removeObject(forKey: vipProductIdKey)
                }
            } else {
                self.isVIP = false
                self.expirationDate = nil
                self.currentProductId = nil
                GVLogger.log("PurchaseManager", "❌ VIP 状态：无有效订阅")
                
                // 清理缓存
                defaults.set(false, forKey: vipFlagKey)
                defaults.removeObject(forKey: vipExpirationKey)
                defaults.removeObject(forKey: vipProductIdKey)
            }
        }
    }
    
    // MARK: - 交易更新监听
    
    /// 监听全局交易更新，防止遗漏在后台完成的成功交易
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                GVLogger.log("PurchaseManager", "监听到交易更新：productID=\(transaction.productID)")
                
                // 有新的有效交易或撤销，刷新本地订阅状态
                await updateSubscriptionStatus()
                
                // 标记该交易已完成，避免重复扣费
                await transaction.finish()
            } catch {
                GVLogger.log("PurchaseManager", "❌ 处理交易更新失败：\(error.localizedDescription)")
            }
        }
    }
    
    /// 从本地缓存还原上一次已知的订阅状态（用于加速启动判断）
    private func restoreCachedSubscriptionState() {
        let defaults = UserDefaults.standard
        
        let cachedFlag = defaults.object(forKey: vipFlagKey) as? Bool ?? false
        let cachedExpirationInterval = defaults.object(forKey: vipExpirationKey) as? TimeInterval
        let cachedProductId = defaults.string(forKey: vipProductIdKey)
        
        if cachedFlag, let interval = cachedExpirationInterval {
            let expiration = Date(timeIntervalSince1970: interval)
            // 仅在未过期时使用缓存，避免长时间离线造成误判
            if expiration > Date() {
                self.isVIP = true
                self.expirationDate = expiration
                self.currentProductId = cachedProductId
                GVLogger.log("PurchaseManager", "🔁 使用本地缓存还原 VIP 状态，过期时间：\(expiration)")
                return
            }
        }
        
        // 缓存不存在或已过期，确保状态为非 VIP
        self.isVIP = false
        self.expirationDate = nil
        self.currentProductId = nil
    }
    
    // MARK: - 交易验证
    
    /// 验证交易（本地验证）
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - 错误类型
    
    enum PurchaseError: Error {
        case failedVerification
    }
    
    enum RestoreResult {
        case restored
        case none
        case failed(Error)
    }
}

