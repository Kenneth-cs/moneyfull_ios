import Foundation

class TokenMonitor {
    static let shared = TokenMonitor()
    
    private let defaults = UserDefaults.standard
    private let totalTokensKey = "totalTokensUsed"
    private let dailyTokensKey = "dailyTokensUsed"
    private let lastResetDateKey = "lastTokenResetDate"
    
    private init() {
        checkAndResetDailyTokens()
    }
    
    /// 记录Token使用量
    func record(tokens: Int) {
        // 累加总使用量
        let totalTokens = defaults.integer(forKey: totalTokensKey) + tokens
        defaults.set(totalTokens, forKey: totalTokensKey)
        
        // 累加每日使用量
        let dailyTokens = defaults.integer(forKey: dailyTokensKey) + tokens
        defaults.set(dailyTokens, forKey: dailyTokensKey)
        
        #if DEBUG
        print("📊 Token使用记录: 本次\(tokens)次，今日累计\(dailyTokens)次，总累计\(totalTokens)次")
        #endif
    }
    
    /// 获取总Token使用量
    func getTotalTokens() -> Int {
        return defaults.integer(forKey: totalTokensKey)
    }
    
    /// 获取今日Token使用量
    func getDailyTokens() -> Int {
        checkAndResetDailyTokens()
        return defaults.integer(forKey: dailyTokensKey)
    }
    
    /// 检查并重置每日Token计数
    private func checkAndResetDailyTokens() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = defaults.object(forKey: lastResetDateKey) as? Date {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            
            if today > lastResetDay {
                defaults.set(0, forKey: dailyTokensKey)
                defaults.set(today, forKey: lastResetDateKey)
                #if DEBUG
                print("🔄 每日Token计数已重置")
                #endif
            }
        } else {
            defaults.set(today, forKey: lastResetDateKey)
        }
    }
    
    /// 估算成本（基于Token数量）
    /// 假设成本区间：¥0.00176 ~ ¥0.00373 每次调用
    /// 平均每次调用约500 tokens
    func estimateCost(tokens: Int) -> (low: Double, high: Double) {
        let calls = Double(tokens) / 500.0
        let lowCost = calls * 0.00176
        let highCost = calls * 0.00373
        return (lowCost, highCost)
    }
    
    /// 获取格式化的成本字符串
    func getFormattedCost() -> String {
        let tokens = getTotalTokens()
        let cost = estimateCost(tokens: tokens)
        return String(format: "¥%.2f ~ ¥%.2f", cost.low, cost.high)
    }
    
    /// 获取格式化的每日成本字符串
    func getFormattedDailyCost() -> String {
        let tokens = getDailyTokens()
        let cost = estimateCost(tokens: tokens)
        return String(format: "¥%.2f ~ ¥%.2f", cost.low, cost.high)
    }
}