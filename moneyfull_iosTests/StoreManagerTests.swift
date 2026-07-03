import XCTest
@testable import moneyfull_ios

/// StoreManager 测试
/// 注意：StoreKit 相关的购买测试需要在真机或 Sandbox 环境中进行
/// 这里主要测试本地逻辑部分
@MainActor
final class StoreManagerTests: XCTestCase {
    
    var sut: StoreManager!
    
    override func setUp() {
        super.setUp()
        sut = StoreManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - SM-001: 初始状态
    func testInitialState_HasPublishedProperties() {
        // 验证 StoreManager 有必要的 Published 属性
        XCTAssertNotNil(sut.isPremium)
        XCTAssertNotNil(sut.fuelCredits)
        XCTAssertNotNil(sut.products)
        XCTAssertNotNil(sut.isLoading)
    }
    
    // MARK: - SM-002: ProductID 枚举
    func testProductID_AllCases() {
        XCTAssertEqual(StoreManager.ProductID.allCases.count, 5)
    }
    
    func testProductID_PremiumMonthly() {
        let id = StoreManager.ProductID.premiumMonthly
        XCTAssertEqual(id.rawValue, "com.moneyfull.premium.monthly")
        XCTAssertTrue(id.isSubscription)
    }
    
    func testProductID_PremiumAnnual() {
        let id = StoreManager.ProductID.premiumAnnual
        XCTAssertEqual(id.rawValue, "com.moneyfull.premium.annual")
        XCTAssertTrue(id.isSubscription)
    }
    
    func testProductID_PremiumLifetime() {
        let id = StoreManager.ProductID.premiumLifetime
        XCTAssertEqual(id.rawValue, "com.moneyfull.premium.lifetime")
        XCTAssertTrue(id.isSubscription)
    }
    
    func testProductID_FuelPack200() {
        let id = StoreManager.ProductID.fuelPack200
        XCTAssertEqual(id.rawValue, "com.moneyfull.fuelpack.200")
        XCTAssertFalse(id.isSubscription)
    }
    
    func testProductID_FuelPack500() {
        let id = StoreManager.ProductID.fuelPack500
        XCTAssertEqual(id.rawValue, "com.moneyfull.fuelpack.500")
        XCTAssertFalse(id.isSubscription)
    }
    
    // MARK: - SM-003: 燃料包使用
    func testUseFuelCredit_WhenAvailable_ReturnsTrue() {
        // 设置初始燃料包
        sut.fuelCredits = 10
        
        let result = sut.useFuelCredit()
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.fuelCredits, 9)
    }
    
    func testUseFuelCredit_WhenEmpty_ReturnsFalse() {
        sut.fuelCredits = 0
        
        let result = sut.useFuelCredit()
        
        XCTAssertFalse(result)
        XCTAssertEqual(sut.fuelCredits, 0)
    }
    
    func testUseFuelCredit_MultipleTimes() {
        sut.fuelCredits = 3
        
        XCTAssertTrue(sut.useFuelCredit())
        XCTAssertTrue(sut.useFuelCredit())
        XCTAssertTrue(sut.useFuelCredit())
        XCTAssertFalse(sut.useFuelCredit())
        XCTAssertEqual(sut.fuelCredits, 0)
    }
    
    // MARK: - SM-004: 燃料包持久化
    func testFuelCredits_Persistence() {
        // 先清空
        sut.fuelCredits = 0
        sut.useFuelCredit() // 确保触发保存
        
        // 设置新值并触发保存
        sut.fuelCredits = 250
        sut.useFuelCredit() // 触发 saveFuelCredits
        
        // 验证内存值
        XCTAssertEqual(sut.fuelCredits, 249)
        
        // 验证持久化（useFuelCredit 会调用 saveFuelCredits）
        let savedValue = UserDefaults.standard.integer(forKey: "fuelCredits")
        XCTAssertEqual(savedValue, 249)
    }
    
    // MARK: - SM-005: ProductID 订阅分类
    func testProductID_SubscriptionTypes() {
        let subscriptions = StoreManager.ProductID.allCases.filter { $0.isSubscription }
        let consumables = StoreManager.ProductID.allCases.filter { !$0.isSubscription }
        
        XCTAssertEqual(subscriptions.count, 3) // monthly, annual, lifetime
        XCTAssertEqual(consumables.count, 2) // fuel200, fuel500
    }
    
    // MARK: - SM-006: Singleton 访问
    func testSharedInstance_ReturnsSameInstance() {
        let instance1 = StoreManager.shared
        let instance2 = StoreManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
}
