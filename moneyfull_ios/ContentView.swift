import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: AppStore?
    // 首次安装才显示引导页，之后永不再出现
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        Group {
            if let store = store {
                MainTabView()
                    .environmentObject(store)
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                    }
            } else {
                // 加载中占位
                Color.App.backgroundGray.ignoresSafeArea()
            }
        }
        .onAppear {
            if store == nil {
                store = AppStore(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Transaction.self, Category.self], inMemory: true)
}
