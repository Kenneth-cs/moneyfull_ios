import SwiftUI
import SwiftData
import UIKit

@main
struct moneyfull_iosApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var budgetAlertService = BudgetAlertService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showJoinFromDeepLink = false
    @State private var deepLinkInviteCode = ""
    
    private let modelContainer: ModelContainer
    
    init() {
        modelContainer = Self.createModelContainer()
        ContextManager.shared.setModelContext(modelContainer.mainContext)
        StoreManager.shared.setModelContext(modelContainer.mainContext)
        // 从 iCloud 恢复画像数据（新设备首次安装时）
        AssessmentEngine.restoreFromiCloudIfNeeded()
        // 通知权限不在启动时请求，由用户在「提醒设置」页主动开启
    }
    
    private static func createModelContainer() -> ModelContainer {
        do {
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            let container = try ModelContainer(
                for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self, ProjectReviewCache.self, LegacyGiftGrant.self, AppNotice.self,
                configurations: config
            )
            #if DEBUG
            print("✅ CloudKit 存储已启用")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ CloudKit 不可用: \(error.localizedDescription)，尝试本地存储...")
            #endif
        }

        do {
            let container = try ModelContainer(
                for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self, ProjectReviewCache.self, LegacyGiftGrant.self, AppNotice.self
            )
            #if DEBUG
            print("✅ 本地存储已启用")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ 本地存储迁移失败: \(error.localizedDescription)，使用内存模式...")
            #endif
        }

        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self, ProjectReviewCache.self, LegacyGiftGrant.self, AppNotice.self,
                configurations: config
            )
            #if DEBUG
            print("⚠️ 内存模式已启用（数据不会持久化）")
            #endif
            return container
        } catch {
            fatalError("无法创建 ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                .environmentObject(storeManager)
                .environmentObject(budgetAlertService)
                .preferredColorScheme(theme.colorScheme)
                .tint(Color.App.darkGreen)
                .onChange(of: scenePhase) { oldValue, newValue in
                    if newValue == .active {
                        // 用户回到前台，取消所有待发的预算预警推送
                        let projects = fetchActiveProjects()
                        for project in projects {
                            budgetAlertService.cancelPendingPush(for: project.id)
                        }
                        // 检查剪贴板：H5 页面在跳转 App Store 前会把邀请码写入剪贴板
                        // 格式：纯 6 位大写字母，或 "moneyfull-invite:XXXXXX"
                        checkClipboardForInviteCode()
                    }
                }
                .onAppear {
                    // App启动时预排未来7天被动推送
                    let projects = fetchActiveProjects()
                    NotificationManager.shared.schedulePassiveBudgetChecks(
                        projects: projects
                    )
                }
                .onOpenURL { url in
                    var extractedCode: String? = nil

                    if url.scheme == "moneyfull", url.host == "join" {
                        // 格式一：moneyfull://join?code=ABCDEF（查询参数）
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let q = components.queryItems?.first(where: { $0.name == "code" })?.value,
                           !q.isEmpty {
                            extractedCode = q
                        } else {
                            // 格式二：moneyfull://join/ABCDEF（路径）
                            let pathCode = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            if !pathCode.isEmpty { extractedCode = pathCode }
                        }
                    }
                    // 格式三：Universal Link https://originapex.cn/join/ABCDEF
                    else if url.scheme == "https",
                            url.host == "originapex.cn",
                            url.pathComponents.count >= 3,
                            url.pathComponents[1] == "join" {
                        let pathCode = url.pathComponents[2]
                        if !pathCode.isEmpty { extractedCode = pathCode }
                    }

                    if let code = extractedCode, !code.isEmpty {
                        deepLinkInviteCode = code.uppercased()
                        showJoinFromDeepLink = true
                    }
                }
                .sheet(isPresented: $showJoinFromDeepLink) {
                    JoinProjectView(prefilledCode: deepLinkInviteCode) { project in
                        // 加入成功后通知 MainTabView 导航到详情页
                        NotificationCenter.default.post(
                            name: .sharedProjectJoinedFromDeepLink,
                            object: nil,
                            userInfo: ["project": project]
                        )
                    }
                }
                // 监听 ContentView 转发的 join deep link（ContentView 的 onOpenURL 是最内层，会先于此处触发）
                .onReceive(NotificationCenter.default.publisher(for: .openJoinProjectFromDeepLink)) { notification in
                    if let code = notification.object as? String {
                        deepLinkInviteCode = code
                        showJoinFromDeepLink = true
                    }
                }
        }
        .modelContainer(modelContainer)
    }
    
    private func fetchActiveProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { !$0.isArchived }
        )
        return (try? modelContainer.mainContext.fetch(descriptor)) ?? []
    }

    /// 检查剪贴板是否含有邀请码（H5 在跳 App Store 前写入）
    /// 为避免误触，只在邀请码未使用过的情况下弹窗（用 UserDefaults 标记已消费的码）
    private func checkClipboardForInviteCode() {
        guard !showJoinFromDeepLink else { return }   // 已有弹窗，不重复
        let raw = UIPasteboard.general.string ?? ""
        var code: String? = nil

        // 格式一："moneyfull-invite:ABCDEF"（H5 优先写入此格式，便于精确识别）
        if raw.hasPrefix("moneyfull-invite:") {
            let candidate = String(raw.dropFirst("moneyfull-invite:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if candidate.count == 6, candidate.allSatisfy({ $0.isLetter || $0.isNumber }) {
                code = candidate
            }
        }
        // 格式二：纯 6 位大写字母数字（兼容旧版 H5 只写邀请码的情况）
        else {
            let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if candidate.count == 6, candidate.allSatisfy({ $0.isLetter || $0.isNumber }) {
                code = candidate
            }
        }

        guard let inviteCode = code else { return }

        // 防止重复弹窗：用 UserDefaults 记录已消费的码
        let consumedKey = "consumed_invite_\(inviteCode)"
        guard !UserDefaults.standard.bool(forKey: consumedKey) else { return }

        // 标记已消费并清空剪贴板，避免重复触发
        UserDefaults.standard.set(true, forKey: consumedKey)
        UIPasteboard.general.string = ""

        // 延迟一帧再弹窗，确保 UI 已就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            deepLinkInviteCode = inviteCode
            showJoinFromDeepLink = true
        }
    }
}
