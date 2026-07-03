import XCTest
@testable import moneyfull_ios

final class TokenMonitorTests: XCTestCase {
    
    var sut: TokenMonitor!
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // 使用独立的 UserDefaults suite 避免污染生产数据
        testDefaults = UserDefaults(suiteName: "test_token_monitor")!
        testDefaults.removePersistentDomain(forName: "test_token_monitor")
        sut = TokenMonitor.shared
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "test_token_monitor")
        sut = nil
        super.tearDown()
    }
    
    // MARK: - TM-001: 记录单次 Token
    func testRecordSingleTokenUsage() {
        let initialTokens = sut.getTotalTokens()
        sut.record(tokens: 150)
        
        XCTAssertEqual(sut.getTotalTokens(), initialTokens + 150)
    }
    
    // MARK: - TM-002: 累计多次 Token
    func testRecordMultipleTokenUsage() {
        let initialTokens = sut.getTotalTokens()
        
        sut.record(tokens: 100)
        sut.record(tokens: 200)
        sut.record(tokens: 300)
        
        XCTAssertEqual(sut.getTotalTokens(), initialTokens + 600)
    }
    
    // MARK: - TM-003: 每日 Token 记录
    func testDailyTokenTracking() {
        let initialDaily = sut.getDailyTokens()
        
        sut.record(tokens: 500)
        
        XCTAssertEqual(sut.getDailyTokens(), initialDaily + 500)
    }
    
    // MARK: - TM-004: 总量和每日独立计算
    func testTotalAndDailyIndependent() {
        sut.record(tokens: 1000)
        
        // 总量应该是累计的
        let total = sut.getTotalTokens()
        XCTAssertGreaterThanOrEqual(total, 1000)
        
        // 每日应该是当天的
        let daily = sut.getDailyTokens()
        XCTAssertGreaterThanOrEqual(daily, 1000)
    }
    
    // MARK: - TM-005: 成本估算
    func testCostEstimation() {
        // 500 tokens = 1 次调用
        let cost = sut.estimateCost(tokens: 500)
        
        XCTAssertEqual(cost.low, 0.00176, accuracy: 0.0001)
        XCTAssertEqual(cost.high, 0.00373, accuracy: 0.0001)
    }
    
    func testCostEstimation_MultipleCalls() {
        // 2500 tokens = 5 次调用
        let cost = sut.estimateCost(tokens: 2500)
        
        XCTAssertEqual(cost.low, 0.0088, accuracy: 0.001)
        XCTAssertEqual(cost.high, 0.01865, accuracy: 0.001)
    }
    
    // MARK: - TM-006: 格式化成本字符串
    func testFormattedCost() {
        sut.record(tokens: 5000)
        
        let formatted = sut.getFormattedCost()
        
        XCTAssertTrue(formatted.hasPrefix("¥"))
        XCTAssertTrue(formatted.contains("~"))
    }
    
    // MARK: - TM-007: 零 Token 记录
    func testRecordZeroTokens() {
        let initial = sut.getTotalTokens()
        sut.record(tokens: 0)
        
        XCTAssertEqual(sut.getTotalTokens(), initial)
    }
    
    // MARK: - TM-008: 大量 Token 记录
    func testRecordLargeTokenAmount() {
        let initial = sut.getTotalTokens()
        sut.record(tokens: 1_000_000)
        
        XCTAssertEqual(sut.getTotalTokens(), initial + 1_000_000)
    }
}
