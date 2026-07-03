import XCTest
import StoreKit
@testable import moneyfull_ios

/// StoreKit 集成测试
/// 注意：这些测试需要在 StoreKit Test 环境中运行
/// 在 Xcode 中：Edit Scheme → Test → Options → StoreKit Configuration → 选择配置文件
@available(iOS 15.0, *)
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    
    var sut: StoreManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = StoreManager.shared
        // 重置状态
        sut.fuelCredits = 0
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - SK-001: 产品加载
    func testLoadProducts_ReturnsAllProducts() async throws {
        await sut.loadProducts()
        
        // 应该加载到 5 个产品
        XCTAssertGreaterThanOrEqual(sut.products.count, 5, "应该加载至少 5 个产品")
        
        // 验证产品 ID 存在
        let productIDs = sut.products.map { $0.id }
        XCTAssertTrue(productIDs.contains(StoreManager.ProductID.premiumMonthly.rawValue))
        XCTAssertTrue(productIDs.contains(StoreManager.ProductID.premiumAnnual.rawValue))
        XCTAssertTrue(productIDs.contains(StoreManager.ProductID.premiumLifetime.rawValue))
        XCTAssertTrue(productIDs.contains(StoreManager.ProductID.fuelPack200.rawValue))
        XCTAssertTrue(productIDs.contains(StoreManager.ProductID.fuelPack500.rawValue))
    }
    
    // MARK: - SK-002: 产品价格验证
    func testProducts_HaveValidPrices() async throws {
        await sut.loadProducts()
        
        for product in sut.products {
            // 每个产品都应该有价格显示
            XCTAssertFalse(product.displayPrice.isEmpty, "产品 \(product.id) 应该有价格")
        }
    }
    
    // MARK: - SK-003: 燃料包 200 次购买
    func testPurchaseFuelPack200_Success() async throws {
        await sut.loadProducts()
        
        guard let fuelPack200 = sut.products.first(where: { 
            $0.id == StoreManager.ProductID.fuelPack200.rawValue 
        }) else {
            XCTFail("找不到燃料包 200 产品")
            return
        }
        
        let initialCredits = sut.fuelCredits
        
        // 购买
        let result = try await sut.purchase(fuelPack200)
        
        XCTAssertTrue(result, "购买应该成功")
        XCTAssertEqual(sut.fuelCredits, initialCredits + 200, "燃料包应该增加 200")
    }
    
    // MARK: - SK-004: 燃料包 500 次购买
    func testPurchaseFuelPack500_Success() async throws {
        await sut.loadProducts()
        
        guard let fuelPack500 = sut.products.first(where: { 
            $0.id == StoreManager.ProductID.fuelPack500.rawValue 
        }) else {
            XCTFail("找不到燃料包 500 产品")
            return
        }
        
        let initialCredits = sut.fuelCredits
        
        // 购买
        let result = try await sut.purchase(fuelPack500)
        
        XCTAssertTrue(result, "购买应该成功")
        XCTAssertEqual(sut.fuelCredits, initialCredits + 500, "燃料包应该增加 500")
    }
    
    // MARK: - SK-005: 燃料包消耗联动
    func testFuelPackConsumption_AfterPurchase() async throws {
        await sut.loadProducts()
        
        guard let fuelPack200 = sut.products.first(where: { 
            $0.id == StoreManager.ProductID.fuelPack200.rawValue 
        }) else {
            XCTFail("找不到燃料包 200 产品")
            return
        }
        
        // 购买
        _ = try await sut.purchase(fuelPack200)
        
        // 消耗 3 次
        XCTAssertTrue(sut.useFuelCredit())
        XCTAssertTrue(sut.useFuelCredit())
        XCTAssertTrue(sut.useFuelCredit())
        
        XCTAssertEqual(sut.fuelCredits, 197, "消耗 3 次后应该剩余 197")
    }
    
    // MARK: - SK-006: 订阅状态验证
    func testPremiumSubscription_IsPremium() async throws {
        await sut.loadProducts()
        
        guard let monthlyProduct = sut.products.first(where: { 
            $0.id == StoreManager.ProductID.premiumMonthly.rawValue 
        }) else {
            XCTFail("找不到月卡产品")
            return
        }
        
        // 购买月卡
        let result = try await sut.purchase(monthlyProduct)
        
        XCTAssertTrue(result, "购买应该成功")
        XCTAssertTrue(sut.isPremium, "购买后应该是 Premium 状态")
    }
    
    // MARK: - SK-007: 恢复购买
    func testRestorePurchases_NoError() async throws {
        // 恢复购买不应该抛出错误
        await sut.restorePurchases()
        
        // 验证加载状态恢复正常
        XCTAssertFalse(sut.isLoading, "恢复购买后不应该处于加载状态")
    }
    
    // MARK: - SK-008: 产品类型验证
    func testProductTypes_Correct() async throws {
        await sut.loadProducts()
        
        // 订阅产品
        let subscriptionIDs = [
            StoreManager.ProductID.premiumMonthly.rawValue,
            StoreManager.ProductID.premiumAnnual.rawValue,
            StoreManager.ProductID.premiumLifetime.rawValue
        ]
        
        // 消耗型产品
        let consumableIDs = [
            StoreManager.ProductID.fuelPack200.rawValue,
            StoreManager.ProductID.fuelPack500.rawValue
        ]
        
        for product in sut.products {
            if subscriptionIDs.contains(product.id) {
                XCTAssertTrue(StoreManager.ProductID(rawValue: product.id)?.isSubscription ?? false, 
                              "\(product.id) 应该是订阅类型")
            } else if consumableIDs.contains(product.id) {
                XCTAssertFalse(StoreManager.ProductID(rawValue: product.id)?.isSubscription ?? true, 
                               "\(product.id) 应该是消耗类型")
            }
        }
    }
}
