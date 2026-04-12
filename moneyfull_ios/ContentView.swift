import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: AppStore?

    var body: some View {
        Group {
            if let store = store {
                MainTabView()
                    .environmentObject(store)
            } else {
                // 加载中占位，避免闪屏
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
