import XCTest
@testable import moneyfull_ios

class AppRatingManagerTests: XCTestCase {
    
    var sut: AppRatingManager!
    var defaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test_rating")!
        defaults.removePersistentDomain(forName: "test_rating")
        sut = AppRatingManager(defaults: defaults)
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: "test_rating")
        sut = nil
        defaults = nil
        super.tearDown()
    }
    
    func testShouldShowRating_WhenAllConditionsMet() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        defaults.set(sevenDaysAgo, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
        
        XCTAssertTrue(sut.shouldShowRating(transactionCount: 15))
    }
    
    func testShouldNotShowRating_WhenAlreadyRated() {
        setupValidConditions()
        defaults.set(true, forKey: "hasRatedApp")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    func testShouldNotShowRating_WhenTransactionCountInsufficient() {
        setupValidConditions()
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 14))
    }
    
    func testShouldNotShowRating_WhenUsageDaysInsufficient() {
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        defaults.set(sixDaysAgo, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    func testShouldNotShowRating_WhenDismissedTooManyTimes() {
        setupValidConditions()
        defaults.set(3, forKey: "ratingDismissCount")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    func testShouldNotShowRating_WithinCooldownPeriod() {
        setupValidConditions()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        defaults.set(tenDaysAgo, forKey: "lastRatingPromptDate")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    func testShouldShowRating_AfterCooldown() {
        setupValidConditions()
        let fifteenDaysAgo = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        defaults.set(fifteenDaysAgo, forKey: "lastRatingPromptDate")
        
        XCTAssertTrue(sut.shouldShowRating(transactionCount: 20))
    }
    
    func testMarkAsRated() {
        sut.markAsRated()
        
        XCTAssertTrue(defaults.bool(forKey: "hasRatedApp"))
    }
    
    func testMarkAsDismissed() {
        defaults.set(1, forKey: "ratingDismissCount")
        
        sut.markAsDismissed()
        
        XCTAssertEqual(defaults.integer(forKey: "ratingDismissCount"), 2)
        XCTAssertNotNil(defaults.object(forKey: "lastRatingPromptDate"))
    }
    
    private func setupValidConditions() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        defaults.set(sevenDaysAgo, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
    }
}
