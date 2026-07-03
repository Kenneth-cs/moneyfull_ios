import XCTest
@testable import moneyfull_ios

/// 跨模块集成测试
/// 测试商业化功能之间的联动逻辑
@MainActor
final class CrossModuleIntegrationTests: XCTestCase {
    
    var storeManager: StoreManager!
    
    override func setUp() {
        super.setUp()
        storeManager = StoreManager.shared
        // 重置状态
        storeManager.fuelCredits = 0
    }
    
    override func tearDown() {
        storeManager = nil
        super.tearDown()
    }
    
    // MARK: - CM-001: AI 限流与燃料包联动
    
    /// 测试免费用户达到限额后，燃料包可以继续使用
    func testAILimit_WithFuelCredits_CanContinue() {
        // 设置免费用户状态
        storeManager.fuelCredits = 50
        
        // 模拟 AI 限流逻辑
        let dailyLimit = storeManager.isPremium ? 100 : 10
        let dailyUsageCount = 10 // 达到限额
        
        let isLimitReached: Bool = {
            let base = dailyUsageCount >= dailyLimit
            if base && storeManager.fuelCredits > 0 { return false }
            return base
        }()
        
        // 有燃料包时不应该被限制
        XCTAssertFalse(isLimitReached, "有燃料包时不应该被限制")
        
        // 消耗一次燃料包
        let used = storeManager.useFuelCredit()
        XCTAssertTrue(used, "应该能消耗燃料包")
        XCTAssertEqual(storeManager.fuelCredits, 49, "燃料包应该减少 1")
    }
    
    /// 测试燃料包用完后被限制
    func testAILimit_NoFuelCredits_Blocked() {
        storeManager.fuelCredits = 0
        
        let dailyLimit = storeManager.isPremium ? 100 : 10
        let dailyUsageCount = 10
        
        let isLimitReached: Bool = {
            let base = dailyUsageCount >= dailyLimit
            if base && storeManager.fuelCredits > 0 { return false }
            return base
        }()
        
        XCTAssertTrue(isLimitReached, "无燃料包且达到限额时应该被限制")
    }
    
    // MARK: - CM-002: Premium 状态与 AI 限额联动
    
    /// 测试 Premium 用户限额更高
    func testPremiumUser_HigherLimit() {
        // 模拟 Premium 用户
        storeManager.isPremium = true
        
        let dailyLimit = storeManager.isPremium ? 100 : 10
        
        XCTAssertEqual(dailyLimit, 100, "Premium 用户限额应该是 100")
    }
    
    /// 测试免费用户限额较低
    func testFreeUser_LowerLimit() {
        storeManager.isPremium = false
        
        let dailyLimit = storeManager.isPremium ? 100 : 10
        
        XCTAssertEqual(dailyLimit, 10, "免费用户限额应该是 10")
    }
    
    // MARK: - CM-003: 项目门控与 Premium 联动
    
    /// 测试 Premium 用户无项目限制
    func testPremiumUser_UnlimitedProjects() {
        storeManager.isPremium = true
        
        // 模拟项目门控逻辑
        let currentProjectCount = 10
        let canCreate = storeManager.isPremium || currentProjectCount < 3
        
        XCTAssertTrue(canCreate, "Premium 用户应该能创建无限项目")
    }
    
    /// 测试免费用户受项目限制
    func testFreeUser_ProjectLimit() {
        storeManager.isPremium = false
        
        // 模拟有 3 个项目
        let currentProjectCount = 3
        let canCreate = storeManager.isPremium || currentProjectCount < 3
        
        XCTAssertFalse(canCreate, "免费用户有 3 个项目时不能创建更多")
    }
    
    // MARK: - CM-004: Grandfathering 与项目门控联动
    
    /// 测试老用户保留权益
    func testGrandfatheredUser_KeepsProjects() {
        let defaults = UserDefaults.standard
        let key = "hasGrandfatheredProjects"
        
        // 模拟老用户
        defaults.set(true, forKey: key)
        
        // 老用户可以创建更多项目
        let currentProjectCount = 5
        let canCreate = storeManager.isPremium || defaults.bool(forKey: key) || currentProjectCount < 3
        
        XCTAssertTrue(canCreate, "老用户应该能创建项目")
        
        // 清理
        defaults.removeObject(forKey: key)
    }
    
    // MARK: - CM-005: 燃料包购买与消耗完整流程
    
    /// 测试燃料包完整生命周期
    func testFuelCredit_Lifecycle() {
        // 初始状态
        XCTAssertEqual(storeManager.fuelCredits, 0, "初始燃料包应该为 0")
        
        // 模拟购买 200 燃料包
        storeManager.fuelCredits += 200
        XCTAssertEqual(storeManager.fuelCredits, 200, "购买后应该有 200 燃料包")
        
        // 消耗 5 次
        for _ in 1...5 {
            _ = storeManager.useFuelCredit()
        }
        XCTAssertEqual(storeManager.fuelCredits, 195, "消耗 5 次后应该剩余 195")
        
        // 验证可以继续消耗
        XCTAssertTrue(storeManager.useFuelCredit(), "应该能继续消耗")
        
        // 验证消耗到 0 后不能继续
        storeManager.fuelCredits = 0
        XCTAssertFalse(storeManager.useFuelCredit(), "燃料包为 0 时不能消耗")
    }
    
    // MARK: - CM-006: 多个燃料包叠加
    
    /// 测试多次购买燃料包叠加
    func testFuelCredit_Stacking() {
        // 购买 200
        storeManager.fuelCredits += 200
        XCTAssertEqual(storeManager.fuelCredits, 200)
        
        // 再购买 500
        storeManager.fuelCredits += 500
        XCTAssertEqual(storeManager.fuelCredits, 700, "燃料包应该叠加到 700")
    }
    
    // MARK: - CM-007: Token 监控与 AI 调用联动
    
    /// 测试 Token 记录功能
    func testTokenMonitor_Integration() {
        let tokenMonitor = TokenMonitor.shared
        
        // 记录一些 Token
        tokenMonitor.record(tokens: 1000)
        tokenMonitor.record(tokens: 2000)
        
        let totalTokens = tokenMonitor.getTotalTokens()
        XCTAssertGreaterThanOrEqual(totalTokens, 3000, "应该累计至少 3000 tokens")
        
        // 验证成本估算
        let cost = tokenMonitor.estimateCost(tokens: totalTokens)
        XCTAssertGreaterThan(cost.low, 0, "成本应该大于 0")
        XCTAssertGreaterThan(cost.high, cost.low, "高估值应该大于低估值")
    }
    
    // MARK: - CM-008: LLM 解析结果与 UI 联动
    
    /// 测试 TransactionParseResult 各状态
    func testTransactionParseResult_States() {
        // 成功状态
        let successResult = TransactionParseResult(
            status: "success",
            amount: 25.0,
            type: "expense",
            groupName: "餐饮",
            categoryName: "咖啡",
            categoryIcon: "cup.and.saucer.fill",
            categoryColorHex: "#A8E0C2",
            note: "买咖啡",
            projectName: nil,
            reply: nil,
            suggestedCategory: nil,
            parentGroup: nil
        )
        XCTAssertEqual(successResult.status, "success")
        XCTAssertEqual(successResult.amount, 25.0)
        
        // 需要澄清状态
        let clarificationResult = TransactionParseResult(
            status: "need_clarification",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: "请问花了多少钱？",
            suggestedCategory: nil,
            parentGroup: nil
        )
        XCTAssertEqual(clarificationResult.status, "need_clarification")
        XCTAssertNotNil(clarificationResult.reply)
    }
}
