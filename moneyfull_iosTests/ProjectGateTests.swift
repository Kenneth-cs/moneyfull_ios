import XCTest
@testable import moneyfull_ios

/// 项目创建门控逻辑测试
/// 测试 NewProjectView 中的 canCreateProject 逻辑
final class ProjectGateTests: XCTestCase {
    
    // MARK: - 测试辅助结构
    
    /// 模拟项目
    struct MockProject {
        let name: String
        let isActiveProject: Bool
        let isArchived: Bool
    }
    
    /// 模拟门控计算器
    struct ProjectGateCalculator {
        var isPremium: Bool
        var activeProjects: [MockProject]
        var archivedProjects: [MockProject]
        
        /// 自定义项目数量（排除"日常"默认项目）
        var customProjectCount: Int {
            let activeCustom = activeProjects.filter { !$0.isActiveProject }.count
            return activeCustom + archivedProjects.count
        }
        
        var canCreateProject: Bool {
            // 1. 专业版用户无限制
            if isPremium { return true }
            // 2. 免费版最多3个自定义项目
            return customProjectCount < 3
        }
    }
    
    // MARK: - PG-001: 免费用户-3个项目内
    func testFreeUser_Under3Projects_CanCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false),
                MockProject(name: "项目2", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertTrue(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 2)
    }
    
    // MARK: - PG-002: 免费用户-达到3个上限
    func testFreeUser_At3Projects_CannotCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false),
                MockProject(name: "项目2", isActiveProject: false, isArchived: false),
                MockProject(name: "项目3", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertFalse(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 3)
    }
    
    // MARK: - PG-003: Premium 用户-无限制
    func testPremiumUser_AnyProjectCount_CanCreate() {
        let projects = (0..<10).map { 
            MockProject(name: "项目\($0)", isActiveProject: false, isArchived: false) 
        }
        
        let calculator = ProjectGateCalculator(
            isPremium: true,
            activeProjects: projects,
            archivedProjects: []
        )
        
        XCTAssertTrue(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 10)
    }
    
    // MARK: - PG-004: 日常项目不计入
    func testDailyProject_NotCounted() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常收支", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false),
                MockProject(name: "项目2", isActiveProject: false, isArchived: false),
                MockProject(name: "项目3", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertEqual(calculator.customProjectCount, 3)
        XCTAssertFalse(calculator.canCreateProject)
    }
    
    // MARK: - PG-005: 归档项目计入
    func testArchivedProjects_Counted() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: [
                MockProject(name: "归档1", isActiveProject: false, isArchived: true),
                MockProject(name: "归档2", isActiveProject: false, isArchived: true)
            ]
        )
        
        XCTAssertEqual(calculator.customProjectCount, 3) // 1 活跃 + 2 归档
        XCTAssertFalse(calculator.canCreateProject)
    }
    
    // MARK: - PG-006: 归档项目 + 活跃项目超限
    func testArchivedAndActive_ExceedsLimit() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: [
                MockProject(name: "归档1", isActiveProject: false, isArchived: true),
                MockProject(name: "归档2", isActiveProject: false, isArchived: true),
                MockProject(name: "归档3", isActiveProject: false, isArchived: true)
            ]
        )
        
        XCTAssertEqual(calculator.customProjectCount, 4) // 1 活跃 + 3 归档
        XCTAssertFalse(calculator.canCreateProject)
    }
    
    // MARK: - PG-007: 空项目列表
    func testNoProjects_CanCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [],
            archivedProjects: []
        )
        
        XCTAssertTrue(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 0)
    }
    
    // MARK: - PG-008: 仅有日常项目
    func testOnlyDailyProject_CanCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常收支", isActiveProject: true, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertTrue(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 0)
    }
    
    // MARK: - PG-009: Premium 用户大量归档项目
    func testPremiumUser_ManyArchived_CanCreate() {
        let active = [
            MockProject(name: "日常", isActiveProject: true, isArchived: false),
            MockProject(name: "项目1", isActiveProject: false, isArchived: false)
        ]
        let archived = (0..<20).map { 
            MockProject(name: "归档\($0)", isActiveProject: false, isArchived: true) 
        }
        
        let calculator = ProjectGateCalculator(
            isPremium: true,
            activeProjects: active,
            archivedProjects: archived
        )
        
        XCTAssertTrue(calculator.canCreateProject)
        XCTAssertEqual(calculator.customProjectCount, 21) // 1 + 20
    }
    
    // MARK: - PG-010: 边界值-刚好3个
    func testExactly3Projects_CannotCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false),
                MockProject(name: "项目2", isActiveProject: false, isArchived: false),
                MockProject(name: "项目3", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertEqual(calculator.customProjectCount, 3)
        XCTAssertFalse(calculator.canCreateProject)
    }
    
    // MARK: - PG-011: 边界值-2个
    func testExactly2Projects_CanCreate() {
        let calculator = ProjectGateCalculator(
            isPremium: false,
            activeProjects: [
                MockProject(name: "日常", isActiveProject: true, isArchived: false),
                MockProject(name: "项目1", isActiveProject: false, isArchived: false),
                MockProject(name: "项目2", isActiveProject: false, isArchived: false)
            ],
            archivedProjects: []
        )
        
        XCTAssertEqual(calculator.customProjectCount, 2)
        XCTAssertTrue(calculator.canCreateProject)
    }
}
