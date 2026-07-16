import Foundation

// MARK: - 结构化复盘输出（替换原有 ProjectReviewResult）

/// 洞察卡片
struct InsightHighlight: Codable, Identifiable {
    var id: String { label }
    let icon: String
    let label: String
    let text: String
}

/// 预算建议
struct BudgetSuggestion: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let reason: String
}

/// 报价建议（搞钱模式）
struct QuoteSuggestion: Codable {
    let suggestedAmount: Double
    let reason: String
}

/// 复盘结果
struct ProjectReviewResult: Codable {
    let highlights: [InsightHighlight]
    let oneLiner: String
    let nextBudgetSuggestions: [BudgetSuggestion]
    let nextQuoteSuggestion: QuoteSuggestion?

    // MARK: - 降级结果（JSON 解析失败时使用）

    static func fallback(message: String = "暂无 AI 分析") -> ProjectReviewResult {
        ProjectReviewResult(
            highlights: [InsightHighlight(icon: "📊", label: "数据概览", text: message)],
            oneLiner: message,
            nextBudgetSuggestions: [],
            nextQuoteSuggestion: nil
        )
    }
}

// MARK: - JSON 解析工具

enum ProjectReviewJSONParser {

    /// 去除 markdown 代码块围栏
    static func stripCodeFence(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // ```json ... ```
        if s.hasPrefix("```") {
            if let endOfFirst = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: endOfFirst)...])
            }
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 把 JSON value 转为 Double（兼容 Int / String / NSNumber）
    static func toDouble(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String, let d = Double(s) { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }

    /// 从原始 LLM content 解析 ProjectReviewResult
    static func parse(content: String) -> ProjectReviewResult? {
        let cleaned = stripCodeFence(content)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // highlights
        let highlights: [InsightHighlight] = (json["highlights"] as? [[String: Any]])?.compactMap { d in
            guard let icon = d["icon"] as? String,
                  let label = d["label"] as? String,
                  let text = d["text"] as? String else { return nil }
            return InsightHighlight(icon: icon, label: label, text: text)
        } ?? []

        let oneLiner = json["one_liner"] as? String ?? "暂无总结"

        // next_budget
        let nextBudget: [BudgetSuggestion] = (json["next_budget"] as? [[String: Any]])?.compactMap { d in
            guard let name = d["name"] as? String,
                  let amount = toDouble(d["amount"]) else { return nil }
            let reason = d["reason"] as? String ?? ""
            return BudgetSuggestion(name: name, amount: amount, reason: reason)
        } ?? []

        // next_quote（搞钱模式可选）
        var quote: QuoteSuggestion? = nil
        if let qd = json["next_quote"] as? [String: Any],
           let amount = toDouble(qd["suggested_amount"]) {
            quote = QuoteSuggestion(suggestedAmount: amount, reason: qd["reason"] as? String ?? "")
        }

        // 至少要有一条 highlight 才算有效
        guard !highlights.isEmpty else { return nil }

        return ProjectReviewResult(
            highlights: highlights, oneLiner: oneLiner,
            nextBudgetSuggestions: nextBudget, nextQuoteSuggestion: quote
        )
    }
}
