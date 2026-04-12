import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @State private var selectedTab = 0
    @State private var isAddRecordPresented = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // ① 底层铺满整屏的背景色，消除顶部/底部白条
            Color.App.backgroundGray.ignoresSafeArea()
            
            // ② 内容区域：TabView 透明背景，内容向上缩进避免被 Tab 栏遮住
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(0)
                
                NavigationView {
                    ProjectsView()
                }
                .navigationViewStyle(.stack)
                .tag(1)
                
                Color.clear.tag(2)
                
                AnalyticsView()
                    .tag(3)
                
                ProfileView()
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(Color.clear) // TabView 本身透明，背景由底层提供
            
            // ③ 自定义底部 Tab 栏（含底部安全区填充）
            CustomBottomTabBar(selectedTab: $selectedTab, isAddRecordPresented: $isAddRecordPresented)
        }
        .fullScreenCover(isPresented: $isAddRecordPresented) {
            AddRecordView()
                .environmentObject(store)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - 自定义底部导航栏
struct CustomBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isAddRecordPresented: Bool
    
    var body: some View {
        // 悬浮胶囊，直接浮在背景色上，不加任何底部填充块
        HStack {
            TabBarItem(icon: "house.fill", title: "首页", isSelected: selectedTab == 0) { selectedTab = 0 }
            Spacer()
            TabBarItem(icon: "square.grid.2x2.fill", title: "项目", isSelected: selectedTab == 1) { selectedTab = 1 }
            Spacer()
            
            // 中央加号按钮（上浮效果）
            Button(action: { isAddRecordPresented = true }) {
                ZStack {
                    Circle()
                        .fill(Color.App.primaryGreen)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.App.primaryGreen.opacity(0.5), radius: 10, x: 0, y: 8)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                }
            }
            .offset(y: -18)
            
            Spacer()
            TabBarItem(icon: "chart.bar.fill", title: "统计", isSelected: selectedTab == 3) { selectedTab = 3 }
            Spacer()
            TabBarItem(icon: "person.fill", title: "我的", isSelected: selectedTab == 4) { selectedTab = 4 }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            Color.App.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Tab 图标 + 文字
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
        .environmentObject(ThemeManager())
}
