import Foundation

// MARK: - 共享项目模型
struct SharedProject: Codable, Identifiable {
    let projectId: String
    let inviteCode: String
    let name: String
    let participantName: String
    let createdAt: Date?

    var id: String { projectId }
}

// MARK: - 共享流水模型
struct SharedTransaction: Codable, Identifiable {
    let id: String
    let deviceId: String
    let participantName: String?
    let payerName: String?
    let participants: [String]?
    let splitMethod: String?
    let amount: Double
    let category: String?
    let note: String?
    let transactionAt: Date
    let isDeleted: Bool
    let serverUpdatedAt: Date?

    var idString: String { id }

    var displayPayerName: String {
        payerName ?? participantName ?? "未知"
    }

    var displayParticipantsText: String {
        guard let participants = participants, !participants.isEmpty else {
            return "全体成员"
        }
        return "\(participants.count)人参与"
    }
}

// MARK: - 已加入的共享项目（本地存储）
struct JoinedSharedProject: Codable, Identifiable, Hashable {
    let projectId: String
    let inviteCode: String
    var name: String
    /// 加入该项目时设置的昵称（独立于全局昵称，每个项目单独保存）
    var participantName: String
    var memberNames: [String]
    var lastSyncTime: Date?

    var id: String { projectId }
    
    var memberCount: Int { memberNames.count }
    var membersDisplay: String { memberNames.joined(separator: " · ") }

    func hash(into hasher: inout Hasher) {
        hasher.combine(projectId)
    }

    static func == (lhs: JoinedSharedProject, rhs: JoinedSharedProject) -> Bool {
        lhs.projectId == rhs.projectId
    }
}

// MARK: - API 响应模型
struct CreateProjectResponse: Codable {
    let projectId: String
    let inviteCode: String
    let name: String
}

struct JoinProjectResponse: Codable {
    let projectId: String
    let name: String
    let members: [ProjectMember]
}

struct ProjectMember: Codable, Identifiable {
    let participantName: String
    let joinedAt: Date

    var id: String { participantName }
}

struct TransactionListResponse: Codable {
    let transactions: [SharedTransaction]
    let serverTime: String
}

struct WriteTransactionResponse: Codable {
    let saved: [String]
    let serverTime: String
}

struct MyProjectsResponse: Codable {
    let projects: [SharedProject]
}

struct SimpleResponse: Codable {
    let ok: Bool
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - 项目详情响应（加入前预览）
struct ProjectInfoResponse: Codable {
    let projectId: String
    let name: String
    let memberCount: Int
    let members: [ProjectMember]
    let createdAt: Date?
}

// MARK: - 成员统计
struct MemberStat: Codable {
    let participantName: String
    let deviceId: String
    let totalPaid: Double
    let totalConsumed: Double
}

struct ProjectStatsResponse: Codable {
    let totalAmount: Double
    let memberStats: [MemberStat]
}
