import Foundation

class SharedProjectService {
    static let shared = SharedProjectService()

    private let baseURL = "https://originapex.cn/shared-api"
    private let joinedProjectsKey = "joinedSharedProjects"

    private init() {}

    // MARK: - 设备ID
    var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "sharedDeviceId") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "sharedDeviceId")
        return id
    }

    // MARK: - 昵称管理
    var myNickname: String {
        get {
            UserDefaults.standard.string(forKey: "sharedNickname") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sharedNickname")
        }
    }

    // MARK: - 已加入的项目管理
    var joinedProjects: [JoinedSharedProject] {
        get {
            guard let data = UserDefaults.standard.data(forKey: joinedProjectsKey),
                  let projects = try? JSONDecoder().decode([JoinedSharedProject].self, from: data) else {
                return []
            }
            return projects
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: joinedProjectsKey)
            }
        }
    }

    func saveJoinedProject(_ project: JoinedSharedProject) {
        var projects = joinedProjects
        if !projects.contains(where: { $0.projectId == project.projectId }) {
            projects.append(project)
            joinedProjects = projects
        }
    }

    func removeJoinedProject(projectId: String) {
        joinedProjects = joinedProjects.filter { $0.projectId != projectId }
    }

    // MARK: - API 调用

    // 创建共享项目
    func createProject(name: String, creatorName: String) async throws -> CreateProjectResponse {
        let body: [String: Any] = [
            "id": UUID().uuidString,
            "name": name,
            "createdByDeviceId": deviceId,
            "creatorName": creatorName
        ]

        let response: CreateProjectResponse = try await request(method: "POST", path: "/", body: body)

        // 自动保存到本地
        let joined = JoinedSharedProject(
            projectId: response.projectId,
            inviteCode: response.inviteCode,
            name: response.name,
            participantName: creatorName,
            memberNames: [creatorName],
            lastSyncTime: nil
        )
        saveJoinedProject(joined)

        return response
    }

    // 通过邀请码加入项目
    func joinProject(inviteCode: String, participantName: String) async throws -> JoinProjectResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = [
            "inviteCode": trimmed,
            "deviceId": deviceId,
            "participantName": participantName
        ]

        let response: JoinProjectResponse = try await request(method: "POST", path: "/join", body: body)

        // 自动保存到本地
        let joined = JoinedSharedProject(
            projectId: response.projectId,
            inviteCode: trimmed,
            name: response.name,
            participantName: participantName,
            memberNames: response.members.map { $0.participantName },
            lastSyncTime: nil
        )
        saveJoinedProject(joined)

        return response
    }

    // 拉取流水（增量同步）
    func fetchTransactions(inviteCode: String, since: Date? = nil) async throws -> TransactionListResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        var path = "/\(trimmed)/transactions?deviceId=\(deviceId)"
        if let since = since {
            let formatter = ISO8601DateFormatter()
            path += "&since=\(formatter.string(from: since))"
        }

        return try await request(method: "GET", path: path)
    }

    // 写入流水
    func writeTransactions(inviteCode: String, transactions: [[String: Any]]) async throws -> WriteTransactionResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = [
            "deviceId": deviceId,
            "transactions": transactions
        ]

        return try await request(method: "POST", path: "/\(trimmed)/transactions", body: body)
    }

    // 删除流水
    func deleteTransaction(inviteCode: String, transactionId: String) async throws {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = ["deviceId": deviceId]
        let _: SimpleResponse = try await request(method: "DELETE", path: "/\(trimmed)/transactions/\(transactionId)", body: body)
    }

    // 退出项目
    func leaveProject(inviteCode: String) async throws {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: SimpleResponse = try await request(method: "DELETE", path: "/\(trimmed)/members/\(deviceId)")
        if let projectId = joinedProjects.first(where: { $0.inviteCode == inviteCode })?.projectId {
            removeJoinedProject(projectId: projectId)
        }
        NotificationCenter.default.post(name: .sharedProjectsDidUpdate, object: nil)
    }

    // 获取项目详情（加入前预览）
    func fetchProjectInfo(inviteCode: String) async throws -> ProjectInfoResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await request(method: "GET", path: "/\(trimmed)/info")
    }

    // 修改项目名称（仅创建者）
    func renameProject(inviteCode: String, newName: String) async throws {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = ["deviceId": deviceId, "name": newName]
        let _: SimpleResponse = try await request(method: "PATCH", path: "/\(trimmed)/name", body: body)
        var projects = joinedProjects
        if let index = projects.firstIndex(where: { $0.inviteCode == trimmed }) {
            projects[index].name = newName
            joinedProjects = projects
            NotificationCenter.default.post(name: .sharedProjectsDidUpdate, object: nil)
        }
    }

    /// 修改当前设备在指定项目中的昵称（只影响本项目，不影响全局）
    func updateMyNickname(inviteCode: String, nickname: String) {
        var projects = joinedProjects
        if let index = projects.firstIndex(where: { $0.inviteCode == inviteCode }) {
            projects[index].participantName = nickname
            joinedProjects = projects
        }
    }

    // 获取成员统计
    func fetchStats(inviteCode: String) async throws -> ProjectStatsResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await request(method: "GET", path: "/\(trimmed)/stats")
    }

    // 同步所有项目
    func syncAll() async {
        for project in joinedProjects {
            do {
                let response = try await fetchTransactions(inviteCode: project.inviteCode, since: project.lastSyncTime)
                // 更新最后同步时间
                if let serverTime = ISO8601DateFormatter().date(from: response.serverTime) {
                    var updated = project
                    updated.lastSyncTime = serverTime
                    var projects = joinedProjects
                    if let index = projects.firstIndex(where: { $0.projectId == project.projectId }) {
                        projects[index] = updated
                        joinedProjects = projects
                    }
                }
                // 这里应该通知UI更新，可以通过NotificationCenter
                NotificationCenter.default.post(name: .sharedProjectDidSync, object: nil, userInfo: ["projectId": project.projectId])
            } catch {
                print("同步项目 \(project.name) 失败: \(error)")
            }
        }
    }

    // MARK: - 网络请求封装

    private func request<T: Decodable>(method: String, path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NetworkError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let formatters: [DateFormatter] = [
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }(),
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }(),
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }(),
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }()
                ]

                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期: \(dateString)")
            }
            return try decoder.decode(T.self, from: data)
        } else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["error"] as? String {
                throw NetworkError.serverError(message)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - 错误类型
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "无效的服务器响应"
        case .serverError(let message):
            return message
        case .httpError(let code):
            switch code {
            case 404: return "请求的资源不存在"
            case 403: return "没有权限执行此操作"
            case 429: return "请求过于频繁，请稍后再试"
            default: return "网络请求失败(\(code))"
            }
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let sharedProjectDidSync = Notification.Name("sharedProjectDidSync")
    static let sharedProjectsDidUpdate = Notification.Name("sharedProjectsDidUpdate")
    /// 共享账单写入服务器成功后广播，详情页监听此通知刷新列表
    static let sharedTransactionDidWrite = Notification.Name("sharedTransactionDidWrite")
    /// 通过深链接加入共享项目成功后广播，SharedProjectListView 监听此通知导航到详情页
    static let sharedProjectJoinedFromDeepLink = Notification.Name("sharedProjectJoinedFromDeepLink")
}
