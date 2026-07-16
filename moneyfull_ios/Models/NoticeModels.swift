import SwiftData
import Foundation

/// 老用户会员福利发放记录（全局唯一一条，随 CloudKit 跨设备同步）
/// 发放后 isGranted 永远不会被重置，避免换设备/重装后被重复判定发放
@Model
final class LegacyGiftGrant {
    var id: UUID = UUID()
    var isGranted: Bool = false
    var grantedAt: Date? = nil
    var expiresAt: Date? = nil

    init() {
        self.id = UUID()
    }
}

/// 站内消息 / 公告（消息中心列表用，随 CloudKit 跨设备同步已读状态）
@Model
final class AppNotice {
    /// 固定业务 ID（如 "legacy_gift_2026"），用于判断某条公告是否已经插入过，避免重复插入
    var noticeID: String = ""
    var title: String = ""
    var receivedAt: Date = Date()
    var isRead: Bool = false

    init(noticeID: String, title: String, receivedAt: Date = Date(), isRead: Bool = false) {
        self.noticeID = noticeID
        self.title = title
        self.receivedAt = receivedAt
        self.isRead = isRead
    }
}
