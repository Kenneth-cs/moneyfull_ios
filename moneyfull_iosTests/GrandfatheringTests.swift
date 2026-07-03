import XCTest
@testable import moneyfull_ios

/// Grandfathering（老用户权益保护）逻辑测试
final class GrandfatheringTests: XCTestCase {
    
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "test_grandfathering")!
        testDefaults.removePersistentDomain(forName: "test_grandfathering")
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "test_grandfathering")
        testDefaults = nil
        super.tearDown()
    }
    
    // MARK: - 测试辅助结构
    
    struct GrandfatheringChecker {
        let defaults: UserDefaults
        let grandfatheringCheckedKey = "grandfatheringChecked"
        let hasGrandfatheredProjectsKey = "hasGrandfatheredProjects"
        
        /// 检查并执行 Grandfathering
        func checkAndExecute(projectCount: Int) {
            guard !defaults.bool(forKey: grandfatheringCheckedKey) else { return }
            
            if projectCount > 3 {
                defaults.set(true, forKey: hasGrandfatheredProjectsKey)
            }
            defaults.set(true, forKey: grandfatheringCheckedKey)
        }
        
        var isChecked: Bool {
            return defaults.bool(forKey: grandfatheringCheckedKey)
        }
        
        var hasGrandfatheredProjects: Bool {
            return defaults.bool(forKey: hasGrandfatheredProjectsKey)
        }
    }
    
    // MARK: - GF-001: 首次检测-项目超限
    func testFirstCheck_ProjectsExceedsLimit_SetsGrandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 5)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertTrue(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-002: 首次检测-项目未超限
    func testFirstCheck_ProjectsUnderLimit_NotGrandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 2)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertFalse(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-003: 首次检测-刚好3个项目
    func testFirstCheck_Exactly3Projects_NotGrandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 3)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertFalse(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-004: 首次检测-4个项目
    func testFirstCheck_4Projects_Grandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 4)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertTrue(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-005: 重复检测-不重复执行
    func testSecondCheck_DoesNotOverride() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        // 第一次检测 - 超限
        checker.checkAndExecute(projectCount: 5)
        XCTAssertTrue(checker.hasGrandfatheredProjects)
        
        // 第二次检测 - 尝试用不同值
        checker.checkAndExecute(projectCount: 1)
        
        // 应该保持第一次的结果
        XCTAssertTrue(checker.isChecked)
        XCTAssertTrue(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-006: 未检测状态
    func testInitialState_NotChecked() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        XCTAssertFalse(checker.isChecked)
        XCTAssertFalse(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-007: 大量项目
    func testFirstCheck_ManyProjects_Grandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 20)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertTrue(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-008: 零个项目
    func testFirstCheck_ZeroProjects_NotGrandfathered() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        checker.checkAndExecute(projectCount: 0)
        
        XCTAssertTrue(checker.isChecked)
        XCTAssertFalse(checker.hasGrandfatheredProjects)
    }
    
    // MARK: - GF-009: 老用户权益判断
    func testGrandfatheredUser_CanCreateMoreProjects() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        // 模拟老用户有 5 个项目
        checker.checkAndExecute(projectCount: 5)
        
        // 老用户应该可以继续创建
        let canCreate = checker.hasGrandfatheredProjects || false
        XCTAssertTrue(canCreate)
    }
    
    // MARK: - GF-010: 新用户受限制
    func testNewUser_SubjectToLimit() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        // 新用户，项目数未超限
        checker.checkAndExecute(projectCount: 2)
        
        // 新用户需要检查项目数量（当前有 2 个项目，还能建 1 个）
        let currentProjectCount = 2
        let canCreate = checker.hasGrandfatheredProjects || currentProjectCount < 3
        XCTAssertTrue(canCreate) // 2 < 3，可以创建
    }
    
    func testNewUser_AtLimit_CannotCreate() {
        let checker = GrandfatheringChecker(defaults: testDefaults)
        
        // 新用户，项目数刚好到限制
        checker.checkAndExecute(projectCount: 3)
        
        // 新用户需要检查项目数量
        let projectCount = 3
        let canCreate = checker.hasGrandfatheredProjects || projectCount < 3
        XCTAssertFalse(canCreate) // 3 不 < 3，不能创建
    }
}
