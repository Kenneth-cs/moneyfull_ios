import XCTest
@testable import moneyfull_ios

class NotificationManagerTests: XCTestCase {
    
    func testIsWeekend_Saturday() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 30
        let saturday = Calendar.current.date(from: components)!
        
        XCTAssertTrue(NotificationManager.isWeekend(date: saturday))
    }
    
    func testIsWeekend_Sunday() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31
        let sunday = Calendar.current.date(from: components)!
        
        XCTAssertTrue(NotificationManager.isWeekend(date: sunday))
    }
    
    func testIsWeekend_Monday() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 1
        let monday = Calendar.current.date(from: components)!
        
        XCTAssertFalse(NotificationManager.isWeekend(date: monday))
    }
    
    func testReminderStyle_WarmMessages() {
        let style = ReminderStyle.warm
        
        XCTAssertEqual(style.messages.count, 5)
        XCTAssertTrue(style.messages.allSatisfy { !$0.isEmpty })
    }
    
    func testReminderStyle_SimpleMessages() {
        let style = ReminderStyle.simple
        
        XCTAssertEqual(style.messages.count, 5)
        XCTAssertTrue(style.messages.allSatisfy { !$0.isEmpty })
    }
    
    func testReminderStyle_FunnyMessages() {
        let style = ReminderStyle.funny
        
        XCTAssertEqual(style.messages.count, 5)
        XCTAssertTrue(style.messages.allSatisfy { !$0.isEmpty })
    }
    
    func testReminderStyle_RawValue() {
        XCTAssertEqual(ReminderStyle.warm.rawValue, "温馨陪伴")
        XCTAssertEqual(ReminderStyle.simple.rawValue, "简洁高效")
        XCTAssertEqual(ReminderStyle.funny.rawValue, "搞笑幽默")
    }
    
    func testReminderStyle_AllCases() {
        XCTAssertEqual(ReminderStyle.allCases.count, 3)
    }
}
