APIkey:
cplt_02a1149fa805ba4a1a43b928a2d974816e106bc094b3fa1c98bc460e27e16917


iOS Swift 接入示例:
#if DEBUG
private let kApiBase = "https://www.superindividual.originapex.cn"
#else
private let kApiBase = "https://www.superindividual.originapex.cn"
#endif
private let kApiKey  = "cplt_02a1149fa805ba4a1a43b928a2d974816e106bc094b3fa1c98bc460e27e16917"

func trackEvent(eventId: String, eventName: String, params: [String: Any]? = nil) {
    let body: [String: Any] = [
        "projectId": "cmo9qaxjq0002wpz0k7spw409",
        "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
        "eventId": eventId, "eventName": eventName,
        "params": params ?? [:],
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        "osVersion": UIDevice.current.systemVersion,
        "occurredAt": ISO8601DateFormatter().string(from: Date())
    ]
    var req = URLRequest(url: URL(string: "\(kApiBase)/api/events")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(kApiKey)", forHTTPHeaderField: "Authorization")
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: req).resume()
}

// ── 使用示例 ──────────────────────────────────────────────
// 记账成功
trackEvent(
    eventId: "record_submit_success",
    eventName: "记账成功",
    params: ["category": "餐饮", "amount_level": "level_1_under100"]
)

// 点击记一笔入口
trackEvent(eventId: "record_click_add", eventName: "点击记一笔入口")

// 完成引导
trackEvent(
    eventId: "onboarding_complete",
    eventName: "完成引导",
    params: ["steps_skipped": 0]
)

// ── V2.0 新增示例（测评与画像）──────────────────────────────
// 测评完成
trackEvent(
    eventId: "assessment_completed",
    eventName: "测评完成",
    params: [
        "habit": "habit_daily",
        "method": "method_other_app",
        "income": "income_salary",
        "jtbd": "jtbd_insight",
        "health_score": 75
    ]
)

// 画像生成
trackEvent(
    eventId: "persona_generated",
    eventName: "画像生成",
    params: [
        "persona_type": "persona_datadriven",
        "persona_name": "数据控进阶者",
        "persona_letter": "D",
        "health_score": 75,
        "habit": "habit_daily",
        "method": "method_other_app",
        "income": "income_salary",
        "jtbd": "jtbd_insight"
    ]
)