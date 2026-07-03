import XCTest
@testable import moneyfull_ios

/// LLMService 测试
/// 注意：实际 API 调用需要网络环境，这里主要测试本地逻辑
final class LLMServiceTests: XCTestCase {
    
    var sut: LLMService!
    
    override func setUp() {
        super.setUp()
        sut = LLMService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - LM-001: Singleton 访问
    func testSharedInstance_ReturnsSameInstance() {
        let instance1 = LLMService.shared
        let instance2 = LLMService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - LM-002: TransactionParseResult 模型 - success
    func testTransactionParseResult_SuccessStatus() {
        let result = TransactionParseResult(
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
        
        XCTAssertEqual(result.status, "success")
        XCTAssertEqual(result.amount, 25.0)
        XCTAssertEqual(result.type, "expense")
        XCTAssertEqual(result.groupName, "餐饮")
        XCTAssertEqual(result.categoryName, "咖啡")
    }
    
    // MARK: - LM-003: TransactionParseResult - need_clarification
    func testTransactionParseResult_NeedClarification() {
        let result = TransactionParseResult(
            status: "need_clarification",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: "请问您是花了多少钱呢？",
            suggestedCategory: nil,
            parentGroup: nil
        )
        
        XCTAssertEqual(result.status, "need_clarification")
        XCTAssertNotNil(result.reply)
        XCTAssertNil(result.amount)
    }
    
    // MARK: - LM-004: TransactionParseResult - chat
    func testTransactionParseResult_Chat() {
        let result = TransactionParseResult(
            status: "chat",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: "您好，我是小满，有什么可以帮助您的吗？",
            suggestedCategory: nil,
            parentGroup: nil
        )
        
        XCTAssertEqual(result.status, "chat")
        XCTAssertNotNil(result.reply)
    }
    
    // MARK: - LM-005: TransactionParseResult - insight
    func testTransactionParseResult_Insight() {
        var result = TransactionParseResult(
            status: "insight",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: "您本月餐饮支出较多",
            suggestedCategory: nil,
            parentGroup: nil
        )
        result.insightType = "category_group"
        result.targetGroup = "餐饮"
        result.period = "this_month"
        
        XCTAssertEqual(result.status, "insight")
        XCTAssertEqual(result.insightType, "category_group")
        XCTAssertEqual(result.targetGroup, "餐饮")
        XCTAssertEqual(result.period, "this_month")
    }
    
    // MARK: - LM-006: TransactionParseResult - suggest_new_category
    func testTransactionParseResult_SuggestNewCategory() {
        let result = TransactionParseResult(
            status: "suggest_new_category",
            amount: 50.0,
            type: "expense",
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: nil,
            suggestedCategory: "宠物用品",
            parentGroup: "生活"
        )
        
        XCTAssertEqual(result.status, "suggest_new_category")
        XCTAssertEqual(result.suggestedCategory, "宠物用品")
        XCTAssertEqual(result.parentGroup, "生活")
    }
    
    // MARK: - LM-007: TransactionParseResult - income type
    func testTransactionParseResult_Income() {
        let result = TransactionParseResult(
            status: "success",
            amount: 5000.0,
            type: "income",
            groupName: "工资",
            categoryName: "月薪",
            categoryIcon: "banknote.fill",
            categoryColorHex: "#4CAF50",
            note: "6月工资",
            projectName: nil,
            reply: nil,
            suggestedCategory: nil,
            parentGroup: nil
        )
        
        XCTAssertEqual(result.type, "income")
        XCTAssertEqual(result.amount, 5000.0)
    }
    
    // MARK: - LM-008: TransactionParseResult - with project
    func testTransactionParseResult_WithProject() {
        let result = TransactionParseResult(
            status: "success",
            amount: 100.0,
            type: "expense",
            groupName: "餐饮",
            categoryName: "外卖",
            categoryIcon: "takeoutbag.and.cup.and.straw.fill",
            categoryColorHex: "#FF9800",
            note: "点外卖",
            projectName: "新疆之旅",
            reply: nil,
            suggestedCategory: nil,
            parentGroup: nil
        )
        
        XCTAssertEqual(result.projectName, "新疆之旅")
    }
    
    // MARK: - LM-009: TransactionParseResult - all nil optional fields
    func testTransactionParseResult_AllNilOptional() {
        let result = TransactionParseResult(
            status: "chat",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: "测试回复",
            suggestedCategory: nil,
            parentGroup: nil
        )
        
        XCTAssertEqual(result.status, "chat")
        XCTAssertNil(result.amount)
        XCTAssertNil(result.type)
        XCTAssertNil(result.groupName)
    }
}
