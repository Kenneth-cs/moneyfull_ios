import Foundation
import StoreKit
import SwiftUI

// 使用类型别名避免与项目的 Transaction 和 AppStore 冲突
typealias StoreTransaction = StoreKit.Transaction

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // MARK: - Published Properties
    @Published var isPremium: Bool = false
    @Published var fuelCredits: Int = 0
    @Published var dailyUsageCount: Int = 0
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var isLoading: Bool = false
    @Published var currentPlanTitle: String = ""
    @Published var currentPlanExpiry: String = ""
    @Published var currentProductID: String = ""
    
    // MARK: - Constants
    private let fuelCreditsKey = "fuelCredits"
    private let lastResetDateKey = "lastResetDate"
    
    // MARK: - Daily Usage Key (date-based, auto-resets each day)
    static var todayUsageKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ai_chat_usage_" + fmt.string(from: Date())
    }
    
    // MARK: - Daily Limit (测试值：Premium=4, Free=2；上线改回 100/10)
    var dailyLimit: Int {
        #if DEBUG
        return isPremium ? 4 : 2
        #else
        return isPremium ? 100 : 10
        #endif
    }
    
    // MARK: - Computed: 是否还能发消息（日额度 OR 燃料包有余量）
    var canSendMessage: Bool {
        dailyUsageCount < dailyLimit || fuelCredits > 0
    }
    
    // MARK: - Computed: 总剩余次数（日额度剩余 + 燃料包余量）
    var totalRemaining: Int {
        max(0, dailyLimit - dailyUsageCount) + fuelCredits
    }
    
    // MARK: - Product IDs
    enum ProductID: String, CaseIterable {
        case premiumMonthly = "com.moneyfull.premium.monthly"
        case premiumAnnual = "com.moneyfull.premium.annual"
        case premiumLifetime = "com.moneyfull.premium.lifetime"
        case fuelPack200 = "com.moneyfull.fuelpack.200"
        case fuelPack500 = "com.moneyfull.fuelpack.500"
        
        var isSubscription: Bool {
            switch self {
            case .premiumMonthly, .premiumAnnual, .premiumLifetime:
                return true
            case .fuelPack200, .fuelPack500:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        loadFuelCredits()
        loadDailyUsage()
        startTransactionListener()
        
        Task {
            await loadProducts()
            await verifyCurrentEntitlements()
        }
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            
            #if DEBUG
            print("✅ 加载了 \(products.count) 个产品")
            #endif
        } catch {
            #if DEBUG
            print("❌ 加载产品失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            await transaction.finish()
            
            if product.type == .autoRenewable {
                isPremium = true
                currentProductID = product.id
                switch product.id {
                case ProductID.premiumMonthly.rawValue: currentPlanTitle = "月卡"
                case ProductID.premiumAnnual.rawValue: currentPlanTitle = "年卡"
                case ProductID.premiumLifetime.rawValue: currentPlanTitle = "终身"
                default: break
                }
                AnalyticsManager.shared.trackEvent(eventId: "premium_purchased", eventName: "订阅购买成功", params: ["product_id": product.id])
            } else if product.type == .consumable {
                addFuelCredits(for: product.id)
                AnalyticsManager.shared.trackEvent(eventId: "fuel_pack_purchased", eventName: "燃料包购买成功", params: ["product_id": product.id])
            }
            
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        await verifyCurrentEntitlements()
        
        AnalyticsManager.shared.trackEvent(eventId: "purchases_restored", eventName: "恢复购买")
    }
    
    // MARK: - Transaction Listener
    private func startTransactionListener() {
        // 使用普通 Task 继承 @MainActor 上下文，避免 Swift 6 并发捕获错误
        Task { [weak self] in
            for await result in StoreTransaction.updates {
                guard let self else { return }
                do {
                    let transaction = try StoreManager.checkVerifiedStatic(result)
                    if transaction.productType == .autoRenewable {
                        self.isPremium = true
                    }
                    await transaction.finish()
                } catch {
                    #if DEBUG
                    print("❌ 交易验证失败: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Verification
    private func verifyCurrentEntitlements() async {
        var hasActiveSubscription = false
        var hasLifetime = false
        var latestProductID = ""
        var latestExpiryDate: Date?
        
        for await result in StoreTransaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = products.first(where: { $0.id == transaction.productID }) {
                        if subscription.id == ProductID.premiumLifetime.rawValue {
                            hasLifetime = true
                        } else {
                            hasActiveSubscription = true
                        }
                        latestProductID = transaction.productID
                        if let expDate = transaction.expirationDate, expDate > (latestExpiryDate ?? .distantPast) {
                            latestExpiryDate = expDate
                        }
                    }
                default:
                    break
                }
            } catch {
                #if DEBUG
                print("❌ 验证失败: \(error.localizedDescription)")
                #endif
            }
        }
        
        await MainActor.run {
            isPremium = hasActiveSubscription || hasLifetime
            currentProductID = latestProductID
            
            // 解析方案名称
            switch latestProductID {
            case ProductID.premiumMonthly.rawValue:
                currentPlanTitle = "月卡"
            case ProductID.premiumAnnual.rawValue:
                currentPlanTitle = "年卡"
            case ProductID.premiumLifetime.rawValue:
                currentPlanTitle = "终身"
            default:
                currentPlanTitle = isPremium ? "专业版" : ""
            }
            
            // 解析到期时间
            if hasLifetime {
                currentPlanExpiry = "永久有效"
            } else if let expiry = latestExpiryDate {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                currentPlanExpiry = "有效期至 \(fmt.string(from: expiry))"
            } else {
                currentPlanExpiry = ""
            }
            
            #if DEBUG
            print("📋 当前订阅: \(currentPlanTitle), ID: \(currentProductID), 到期: \(currentPlanExpiry)")
            #endif
        }
    }
    
    // MARK: - Verification Helper
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // 静态版本，用于在Task.detached中调用
    nonisolated static func checkVerifiedStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Fuel Credits Management
    private func loadFuelCredits() {
        fuelCredits = UserDefaults.standard.integer(forKey: fuelCreditsKey)
    }
    
    private func addFuelCredits(for productID: String) {
        let creditsToAdd: Int
        
        switch productID {
        case ProductID.fuelPack200.rawValue:
            #if DEBUG
            creditsToAdd = 3  // TEST: 上线改回 200
            #else
            creditsToAdd = 200
            #endif
        case ProductID.fuelPack500.rawValue:
            #if DEBUG
            creditsToAdd = 5  // TEST: 上线改回 500
            #else
            creditsToAdd = 500
            #endif
        default:
            return
        }
        
        fuelCredits += creditsToAdd
        saveFuelCredits()
        
        #if DEBUG
        print("✅ 添加燃料包: \(creditsToAdd) 次，当前余额: \(fuelCredits) 次，总剩余: \(totalRemaining) 次")
        #endif
    }
    
    private func useFuelCredit() -> Bool {
        guard fuelCredits > 0 else { return false }
        
        fuelCredits -= 1
        saveFuelCredits()
        
        #if DEBUG
        print("⚡ 消耗燃料包: 1 次，剩余燃料包: \(fuelCredits) 次")
        #endif
        
        return true
    }
    
    private func saveFuelCredits() {
        UserDefaults.standard.set(fuelCredits, forKey: fuelCreditsKey)
    }
    
    // MARK: - Daily Usage Management
    
    private func loadDailyUsage() {
        dailyUsageCount = UserDefaults.standard.integer(forKey: Self.todayUsageKey)
        #if DEBUG
        print("📅 加载今日用量: \(dailyUsageCount)/\(dailyLimit)")
        #endif
    }
    
    /// 每次打开 AIChatView 时调用，确保日期切换后 dailyUsageCount 归零
    func refreshDailyUsageIfNeeded() {
        let fresh = UserDefaults.standard.integer(forKey: Self.todayUsageKey)
        if fresh != dailyUsageCount {
            dailyUsageCount = fresh
        }
    }
    
    private func saveDailyUsage() {
        UserDefaults.standard.set(dailyUsageCount, forKey: Self.todayUsageKey)
    }
    
    // MARK: - 统一消耗入口（优先日额度，再消耗燃料包）
    func consumeOneCall() -> Bool {
        if dailyUsageCount < dailyLimit {
            // 优先消耗每日额度
            dailyUsageCount += 1
            saveDailyUsage()
            #if DEBUG
            print("✅ 消耗日额度: \(dailyUsageCount)/\(dailyLimit)，总剩余: \(totalRemaining) 次")
            #endif
            return true
        } else if fuelCredits > 0 {
            // 日额度耗尽，改用燃料包
            return useFuelCredit()
        }
        #if DEBUG
        print("❌ 次数耗尽: 日额度 \(dailyUsageCount)/\(dailyLimit)，燃料包: \(fuelCredits)")
        #endif
        return false
    }
    
    // MARK: - Daily Reset (dailyUsageCount 通过 todayKey 日期切换自动归零，无需手动重置)
    
    // MARK: - Offer Code
    func presentOfferCodeSheet() {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let scene else {
            #if DEBUG
            print("❌ 兑换码弹窗失败: 找不到 foregroundActive scene")
            #endif
            return
        }
        Task { @MainActor in
            try? await StoreKit.AppStore.presentOfferCodeRedeemSheet(in: scene)
        }
    }
    
    // MARK: - Helper Methods
    func getPremiumProducts() -> [Product] {
        return products.filter { $0.type == .autoRenewable }
    }
    
    func getFuelPackProducts() -> [Product] {
        return products.filter { $0.type == .consumable }
    }
    
    /// 已废弃，请使用 dailyLimit 属性
    func getDailyLimit() -> Int { dailyLimit }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
    case productNotFound
}

// MARK: - Product Extension
extension Product {
    var localizedPrice: String {
        return displayPrice
    }
    
    var monthlyPrice: String? {
        guard let subscription = subscription else { return nil }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return displayPrice
        case .year:
            let priceValue = Double(truncating: NSDecimalNumber(decimal: price))
            let monthly = priceValue / 12
            return String(format: "%.2f", monthly)
        default:
            return nil
        }
    }
}