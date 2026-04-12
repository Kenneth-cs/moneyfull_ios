import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @State private var selectedTab = 0
    @State private var isAddRecordPresented = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(0)
                
                NavigationView {
                    ProjectsView()
                }
                .navigationViewStyle(.stack)
                .tag(1)
                
                // Placeholder for center button space
                Color.clear
                    .tag(2)
                
                AnalyticsView()
                    .tag(3)
                
                ProfileView()
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Optional: can use normal TabView if we want native, but custom bottom bar is better for this design.
            
            // We use a custom bottom navigation bar
            CustomBottomTabBar(selectedTab: $selectedTab, isAddRecordPresented: $isAddRecordPresented)
        }
        .fullScreenCover(isPresented: $isAddRecordPresented) {
            AddRecordView()
                .environmentObject(store)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct CustomBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isAddRecordPresented: Bool
    
    var body: some View {
        HStack {
            TabBarItem(icon: "house.fill", title: "首页", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            Spacer()
            TabBarItem(icon: "square.grid.2x2.fill", title: "项目", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            Spacer()
            
            // Center Add Button
            Button(action: {
                isAddRecordPresented = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.App.primaryGreen)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.App.primaryGreen.opacity(0.5), radius: 10, x: 0, y: 10)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                }
            }
            .offset(y: -20)
            
            Spacer()
            TabBarItem(icon: "chart.bar.fill", title: "统计", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
            Spacer()
            TabBarItem(icon: "person.fill", title: "我的", isSelected: selectedTab == 4) {
                selectedTab = 4
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 34) // Safe area padding approximation
        .background(
            Color.App.cardBackground.opacity(0.95)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.App.primaryGreen.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? Color.App.darkGreen : Color.gray.opacity(0.5))
                }
                .frame(width: 44, height: 44)
                
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? Color.App.darkGreen : Color.gray.opacity(0.5))
            }
        }
    }
}

#Preview {
    MainTabView()
}
