import SwiftUI
import SwiftData

@main
struct moneyfull_iosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 注册所有 SwiftData 模型，开启本地持久化
        .modelContainer(for: [Project.self, Transaction.self, Category.self])
    }
}
