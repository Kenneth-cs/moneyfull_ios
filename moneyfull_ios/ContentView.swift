import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: AppStore?
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

