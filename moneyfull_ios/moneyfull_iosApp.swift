import SwiftUI
import SwiftData

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
                        // 加入成功后通知 SharedProjectListView 导航到详情页
                        NotificationCenter.default.post(
                            name: .sharedProjectJoinedFromDeepLink,
                            object: nil,
                            userInfo: ["project": project]
                        )
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
}
