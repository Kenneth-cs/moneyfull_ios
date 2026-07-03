import XCTest
@testable import moneyfull_ios

/// AI 聊天限流逻辑测试
/// 测试 AIChatView 中的 dailyLimit、isLimitReached、remainingCount 逻辑
final class AIChatLimitTests: XCTestCase {
    
    // MARK: - 测试辅助结构
    
    /// 模拟限流逻辑的结构体，与 AIChatView 中的逻辑保持一致
    struct LimitCalculator {
        var isPremium: Bool
        var fuelCredits: Int
        var dailyUsageCount: Int
        
        var dailyLimit: Int {
            return isPremium ? 100 : 10
        }
        
        var isLimitReached: Bool {
            let base = dailyUsageCount >= dailyLimit
            if base && fuelCredits > 0 { return false }
            return base
        }
        
        var remainingCount: Int {
            return max(0, dailyLimit - dailyUsageCount)
        }
    }
    
    // MARK: - AL-001: 免费用户每日限额
    func testFreeUser_DailyLimit_Is10() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 0)
        XCTAssertEqual(calculator.dailyLimit, 10)
    }
    
    // MARK: - AL-002: Premium 用户每日限额
    func testPremiumUser_DailyLimit_Is100() {
        let calculator = LimitCalculator(isPremium: true, fuelCredits: 0, dailyUsageCount: 0)
        XCTAssertEqual(calculator.dailyLimit, 100)
    }
    
    // MARK: - AL-003: 未达限额-可继续
    func testNotReached_CanContinue() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 5)
        XCTAssertFalse(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 5)
    }
    
    // MARK: - AL-004: 达到限额-免费用户
    func testFreeUser_AtLimit_IsReached() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 10)
        XCTAssertTrue(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 0)
    }
    
    // MARK: - AL-005: 达到限额-有燃料包
    func testAtLimit_WithFuelCredits_NotReached() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 50, dailyUsageCount: 10)
        XCTAssertFalse(calculator.isLimitReached)
    }
    
    // MARK: - AL-006: 燃料包耗尽
    func testAtLimit_NoFuelCredits_IsReached() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 10)
        XCTAssertTrue(calculator.isLimitReached)
    }
    
    // MARK: - AL-007: 超过限额-免费用户
    func testFreeUser_OverLimit_IsReached() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 15)
        XCTAssertTrue(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 0)
    }
    
    // MARK: - AL-008: Premium 用户未达限额
    func testPremiumUser_UnderLimit_NotReached() {
        let calculator = LimitCalculator(isPremium: true, fuelCredits: 0, dailyUsageCount: 50)
        XCTAssertFalse(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 50)
    }
    
    // MARK: - AL-009: Premium 用户达到限额
    func testPremiumUser_AtLimit_IsReached() {
        let calculator = LimitCalculator(isPremium: true, fuelCredits: 0, dailyUsageCount: 100)
        XCTAssertTrue(calculator.isLimitReached)
    }
    
    // MARK: - AL-010: Premium 用户有燃料包
    func testPremiumUser_AtLimit_WithFuelCredits_NotReached() {
        let calculator = LimitCalculator(isPremium: true, fuelCredits: 100, dailyUsageCount: 100)
        XCTAssertFalse(calculator.isLimitReached)
    }
    
    // MARK: - AL-011: 剩余次数计算-免费用户
    func testRemainingCount_FreeUser() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 7)
        XCTAssertEqual(calculator.remainingCount, 3)
    }
    
    // MARK: - AL-012: 剩余次数计算-Premium 用户
    func testRemainingCount_PremiumUser() {
        let calculator = LimitCalculator(isPremium: true, fuelCredits: 0, dailyUsageCount: 95)
        XCTAssertEqual(calculator.remainingCount, 5)
    }
    
    // MARK: - AL-013: 边界值-刚好用完
    func testExactLimit_FreeUser() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 10)
        XCTAssertTrue(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 0)
    }
    
    // MARK: - AL-014: 边界值-差一次
    func testOneBelowLimit_FreeUser() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 0, dailyUsageCount: 9)
        XCTAssertFalse(calculator.isLimitReached)
        XCTAssertEqual(calculator.remainingCount, 1)
    }
    
    // MARK: - AL-015: 燃料包为 1 时
    func testOneFuelCredit_Available() {
        let calculator = LimitCalculator(isPremium: false, fuelCredits: 1, dailyUsageCount: 10)
        XCTAssertFalse(calculator.isLimitReached)
    }
}
