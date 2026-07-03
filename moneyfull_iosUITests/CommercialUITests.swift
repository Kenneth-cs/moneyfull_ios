import XCTest

/// 商业化功能 UI 自动化测试
/// 测试 Paywall、项目创建门控、AI 限额等 UI 交互
final class CommercialUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    // MARK: - Paywall UI 测试
    
    /// PU-001: Paywall 页面展示
    func testPaywall_DisplaysCorrectly() throws {
        // 导航到 Paywall（通过个人中心）
        navigateToPaywall()
        
        // 验证标题存在
        XCTAssertTrue(app.staticTexts["升级 Premium"].waitForExistence(timeout: 5), 
                      "应该显示升级 Premium 标题")
        
        // 验证三档定价存在
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '月卡'")).element.exists,
                      "应该显示月卡选项")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '年卡'")).element.exists,
                      "应该显示年卡选项")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '终身'")).element.exists,
                      "应该显示终身选项")
    }
    
    /// PU-002: Paywall 功能列表展示
    func testPaywall_ShowsFeatures() throws {
        navigateToPaywall()
        
        // 验证功能列表
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '100次'")).element.waitForExistence(timeout: 5),
                      "应该显示每日 100 次 AI 调用")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '无限项目'")).element.exists,
                      "应该显示无限项目")
    }
    
    /// PU-003: Paywall 底部操作按钮
    func testPaywall_ShowsActionButtons() throws {
        navigateToPaywall()
        
        // 验证恢复购买和兑换码按钮
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS '恢复购买'")).element.exists,
                      "应该显示恢复购买按钮")
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS '兑换码'")).element.exists,
                      "应该显示兑换码按钮")
    }
    
    // MARK: - 项目创建门控 UI 测试
    
    /// PG-UI-001: 免费用户创建项目被拦截
    func testProjectGate_FreeUserBlocked() throws {
        // 先确保是免费用户状态
        // 导航到项目页面
        app.tabBars.buttons["项目"].tap()
        
        // 尝试创建多个项目（模拟达到上限）
        for i in 1...3 {
            app.buttons["添加项目"].tap()
            app.textFields["项目名称"].tap()
            app.textFields["项目名称"].typeText("测试项目\(i)")
            app.buttons["保存"].tap()
            
            // 等待保存完成
            sleep(1)
        }
        
        // 第 4 次创建应该被拦截
        app.buttons["添加项目"].tap()
        app.textFields["项目名称"].tap()
        app.textFields["项目名称"].typeText("第四个项目")
        app.buttons["保存"].tap()
        
        // 应该显示升级提示
        XCTAssertTrue(app.alerts.element.waitForExistence(timeout: 3) || 
                      app.sheets.element.waitForExistence(timeout: 3),
                      "应该显示升级提示或 Paywall")
    }
    
    // MARK: - AI 聊天限额 UI 测试
    
    /// AI-UI-001: AI 聊天页面显示剩余次数
    func testAIChat_ShowsRemainingCount() throws {
        // 导航到 AI 聊天
        app.tabBars.buttons["AI"].tap()
        
        // 验证显示剩余次数
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '剩余'")).element.waitForExistence(timeout: 5),
                      "应该显示剩余次数")
    }
    
    /// AI-UI-002: AI 聊天输入框可用
    func testAIChat_InputFieldAvailable() throws {
        app.tabBars.buttons["AI"].tap()
        
        // 验证输入框存在
        let inputField = app.textViews.firstMatch
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "输入框应该存在")
    }
    
    /// AI-UI-003: AI 聊天快速操作按钮
    func testAIChat_QuickActionsAvailable() throws {
        app.tabBars.buttons["AI"].tap()
        
        // 验证快速操作按钮
        XCTAssertTrue(app.buttons["无疼记账"].waitForExistence(timeout: 5),
                      "应该显示无疼记账按钮")
    }
    
    // MARK: - 个人中心订阅管理 UI 测试
    
    /// PF-UI-001: 个人中心显示订阅状态
    func testProfile_ShowsSubscriptionStatus() throws {
        // 导航到个人中心
        app.tabBars.buttons["个人中心"].tap()
        
        // 验证显示订阅相关信息
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '订阅' OR label CONTAINS 'Premium' OR label CONTAINS '升级'")).element.waitForExistence(timeout: 5),
                      "应该显示订阅状态或升级入口")
    }
    
    /// PF-UI-002: 个人中心显示兑换码入口
    func testProfile_ShowsOfferCodeEntry() throws {
        app.tabBars.buttons["个人中心"].tap()
        
        // 验证兑换码入口
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS '兑换'")).element.waitForExistence(timeout: 5),
                      "应该显示兑换码入口")
    }
    
    // MARK: - 导航测试
    
    /// NAV-001: 主要 Tab 导航
    func testMainTabBar_AllTabsAccessible() throws {
        let tabBar = app.tabBars.firstMatch
        
        // 验证所有 Tab 存在
        XCTAssertTrue(tabBar.buttons["AI"].exists, "AI Tab 应该存在")
        XCTAssertTrue(tabBar.buttons["项目"].exists, "项目 Tab 应该存在")
        XCTAssertTrue(tabBar.buttons["个人中心"].exists, "个人中心 Tab 应该存在")
        
        // 测试切换
        tabBar.buttons["项目"].tap()
        tabBar.buttons["AI"].tap()
        tabBar.buttons["个人中心"].tap()
    }
    
    // MARK: - 辅助方法
    
    private func navigateToPaywall() {
        app.tabBars.buttons["个人中心"].tap()
        
        // 查找升级按钮
        let upgradeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS '升级' OR label CONTAINS 'Premium'")).element
        if upgradeButton.waitForExistence(timeout: 5) {
            upgradeButton.tap()
        }
    }
}
