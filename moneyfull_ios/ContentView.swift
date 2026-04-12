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
                    .preferredColorScheme(.light)
            } else {
                Color.clear // 等待初始化
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
