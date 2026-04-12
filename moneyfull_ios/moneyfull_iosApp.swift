import SwiftUI
import SwiftData

@main
struct moneyfull_iosApp: App {
    @StateObject private var theme = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                // 根据主题偏好应用颜色方案（nil = 跟随系统）
                .preferredColorScheme(theme.colorScheme)
        }
        .modelContainer(for: [Project.self, Transaction.self, Category.self])
    }
}
