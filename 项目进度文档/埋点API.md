APIkey:
sk_live_***


iOS Swift 接入示例:
func trackEvent(
    eventId: String,
    eventName: String,
    params: [String: Any]? = nil
) {
    let body: [String: Any] = [
        "projectId": "cmo7gfgnz000212b7sguan1l4",
        "deviceId": UIDevice.current
            .identifierForVendor?.uuidString ?? "unknown",
        "eventId": eventId,
        "eventName": eventName,
        "params": params ?? [:],
        "appVersion": Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"] as? String ?? "1.0",
        "osVersion": UIDevice.current.systemVersion,
        "occurredAt": ISO8601DateFormatter()
            .string(from: Date())
    ]
    var req = URLRequest(
        url: URL(string: "http://124.222.88.25/api/events")!
    )
    req.httpMethod = "POST"
    req.setValue("application/json",
        forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer sk_live_***",
        forHTTPHeaderField: "Authorization")
    req.httpBody = try? JSONSerialization
        .data(withJSONObject: body)
    URLSession.shared.dataTask(with: req).resume()
}

// 使用示例：
trackEvent(
    eventId: "record_submit_success",
    eventName: "记账成功",
    params: ["category": "餐饮", "amount_level": "level_1_under100"]
)