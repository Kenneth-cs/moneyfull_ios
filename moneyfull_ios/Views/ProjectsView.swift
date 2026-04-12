import SwiftUI

struct ProjectsView: View {
    @State private var selectedTab = 0 // 0 for Ongoing, 1 for Archived
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 9, height: 9)
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 6, height: 6)
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 3, height: 3)
                        }
                        Text("项目中心")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                    }
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Tabs
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        Text("进行中")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedTab == 0 ? Color.App.darkGreen : Color.App.textBlack.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 0 ? Color.App.primaryGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: { selectedTab = 1 }) {
                        Text("已归档")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedTab == 1 ? Color.App.darkGreen : Color.App.textBlack.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 1 ? Color.App.primaryGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(4)
                .background(Color.App.tabBackground)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                
                // Project List
                VStack(spacing: 24) {
                    ProjectDetailCard(
                        icon: "house.fill", iconColor: Color.App.darkGreen, iconBg: Color.App.primaryGreen.opacity(0.3),
                        title: "海景房装修", date: "创建于 2023年10月12日", status: "进行中",
                        desc: "温馨自然的北欧风格，注重采光与海景视野的最大化，打造宁静的度假居住空间。",
                        progress: 0.75, spent: "75,000", remaining: "25,000",
                        progressColor: Color.App.darkGreen, btnBg: Color.App.primaryGreen, btnColor: Color.App.darkGreen
                    )
                    
                    ProjectDetailCard(
                        icon: "paintpalette.fill", iconColor: Color.App.darkOrangeBrown, iconBg: Color.App.lightOrange.opacity(0.3),
                        title: "品牌重塑项目", date: "创建于 2023年11月05日", status: "策划中",
                        statusBg: Color.App.lightYellow, statusColor: Color.App.darkYellow,
                        desc: "为本地精品咖啡馆设计的全新视觉系统，包括LOGO、包装及线上社交媒体视觉。",
                        progress: 0.32, spent: "3,200", remaining: "6,800",
                        progressColor: Color.App.darkOrangeBrown, btnBg: Color.App.lightOrange, btnColor: Color.App.darkOrangeBrown
                    )
                    
                    // Add New Project Button
                    Button(action: {
                        // Handle new project
                    }) {
                        VStack(spacing: 16) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color.App.textBlack.opacity(0.6))
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            Text("新建项目")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(Color.App.textBlack.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.App.tabBackground.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(style: StrokeStyle(lineWidth: 4, dash: [10]))
                                .foregroundColor(Color.gray.opacity(0.3))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 120) // padding for bottom nav
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
}

struct ProjectDetailCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let date: String
    let status: String
    var statusBg: Color = Color.App.lightOrange
    var statusColor: Color = Color.App.darkOrangeBrown
    let desc: String
    let progress: Double
    let spent: String
    let remaining: String
    let progressColor: Color
    let btnBg: Color
    let btnColor: Color
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
            
            // Decorative blur circle
            Circle()
                .fill(iconBg)
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .offset(x: 100, y: -80)
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(iconBg)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: icon)
                                    .foregroundColor(iconColor)
                                    .font(.system(size: 20))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                            Text(date)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Text(status)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusBg)
                        .clipShape(Capsule())
                }
                
                // Description
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineSpacing(4)
                
                // Progress
                VStack(spacing: 8) {
                    HStack {
                        Text("预算进度")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 12)
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [iconBg, progressColor], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * progress, height: 12)
                        }
                    }
                    .frame(height: 12)
                    
                    HStack {
                        Text("已用: ¥\(spent)")
                        Spacer()
                        Text("剩余预算: ¥\(remaining)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                }
                
                // Button
                Button(action: {
                    // navigate to details
                }) {
                    HStack {
                        Text("查看详情")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(btnColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(btnBg)
                    .clipShape(Capsule())
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    ProjectsView()
}
