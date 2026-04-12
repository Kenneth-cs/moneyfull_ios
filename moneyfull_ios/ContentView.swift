import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
            .preferredColorScheme(.light) // As per mockup, it's mostly light
    }
}

#Preview {
    ContentView()
}
