import Foundation
import UIKit
import StoreKit

class AppRatingManager {
    static let shared = AppRatingManager()
    
    private let defaults: UserDefaults
    
    private enum Keys {
        static let firstLaunchDate = "firstLaunchDate"
        static let hasRatedApp = "hasRatedApp"
        static let ratingDismissCount = "ratingDismissCount"
        static let lastRatingPromptDate = "lastRatingPromptDate"
    }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        if defaults.object(forKey: Keys.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: Keys.firstLaunchDate)
        }
    }
    
    func shouldShowRating(transactionCount: Int) -> Bool {
        if defaults.bool(forKey: Keys.hasRatedApp) {
            return false
        }
        
        if defaults.integer(forKey: Keys.ratingDismissCount) >= 3 {
            return false
        }
        
        guard let firstLaunch = defaults.object(forKey: Keys.firstLaunchDate) as? Date else {
            return false
        }
        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        if daysSinceLaunch < 7 {
            return false
        }
        
        if transactionCount < 15 {
            return false
        }
        
        if let lastPrompt = defaults.object(forKey: Keys.lastRatingPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if daysSinceLastPrompt < 14 {
                return false
            }
        }
        
        return true
    }
    
    func markAsRated() {
        defaults.set(true, forKey: Keys.hasRatedApp)
        AnalyticsManager.shared.trackEvent(eventId: "rating_prompt_rate", eventName: "用户评分")
    }
    
    func markAsDismissed() {
        let count = defaults.integer(forKey: Keys.ratingDismissCount)
        defaults.set(count + 1, forKey: Keys.ratingDismissCount)
        defaults.set(Date(), forKey: Keys.lastRatingPromptDate)
        AnalyticsManager.shared.trackEvent(eventId: "rating_prompt_dismiss", eventName: "用户暂不评分")
    }
    
    func requestSystemReview() {
        markAsRated()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    func openAppStore() {
        markAsRated()
        
        let appStoreURL = "https://apps.apple.com/cn/app/%E9%92%B1%E5%B0%8F%E6%BB%A1-%E6%B2%BB%E6%84%88%E7%B3%BB%E9%A1%B9%E7%9B%AE%E8%AE%B0%E8%B4%A6%E7%AE%A1%E5%AE%B6/id6762140727"
        if let url = URL(string: appStoreURL) {
            UIApplication.shared.open(url)
        }
    }
}
