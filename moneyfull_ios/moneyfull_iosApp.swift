import SwiftUI
import SwiftData

@main
struct moneyfull_iosApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var storeManager = StoreManager.shared
    
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
                .preferredColorScheme(theme.colorScheme)
                .tint(Color.App.darkGreen)
        }
        .modelContainer(modelContainer)
    }
}
