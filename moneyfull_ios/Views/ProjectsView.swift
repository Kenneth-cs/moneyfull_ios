import SwiftUI
import SwiftData

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0
    @State private var showNewProject = false
    @State private var showManage = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                ZStack {
                    Text("项目中心")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    HStack {
                        AppLogo()
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            AnalyticsManager.shared.trackEvent(eventId: "project_click_manage", eventName: "点击项目管理")
                            showManage = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20))
                                .foregroundColor(Color.App.darkGreen)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // MARK: 进行中 / 已归档 Tab
                HStack {
                    tabButton(label: "进行中", idx: 0)
                    tabButton(label: "已归档", idx: 1)
                }
                .padding(4)
                .background(Color.App.tabBackground)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                
                // MARK: 项目列表
                let projects = selectedTab == 0 ? store.activeProjects : store.archivedProjects
                
                VStack(spacing: 20) {
                    if projects.isEmpty {
                        VStack(spacing: 16) {
                            Text("🦫")
                                .font(.system(size: 60))
                            Text(selectedTab == 0 ? "还没有进行中的项目" : "还没有归档的项目")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text(selectedTab == 0
                                 ? "可以新建一个项目，比如：\n「旅行」「装修」「日常开销」"
                                 : "完成的项目可以归档整理，\n这里会保留所有历史数据")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                            
                            if selectedTab == 0 {
                                Text("慢慢规划，不着急，我在这儿陪你 🌱")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.App.darkGreen.opacity(0.7))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color.App.primaryGreen.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        .padding(.horizontal, 32)
                    } else {
                        ForEach(projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project).onAppear {
                                AnalyticsManager.shared.trackEvent(eventId: "project_view_detail", eventName: "查看项目详情", params: ["project_status": selectedTab == 0 ? "active" : "archived", "source": "project_center"])
                            }) {
                                ProjectDetailCard(project: project)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 新建项目按钮（仅进行中 tab 显示）
                    if selectedTab == 0 {
                        Button(action: {
                            AnalyticsManager.shared.trackEvent(eventId: "project_click_new", eventName: "点击新建项目")
                            showNewProject = true
                        }) {
                            VStack(spacing: 14) {
                                Circle()
                            .fill(Color.App.cardBackground)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color.App.textBlack.opacity(0.6))
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                Text("新建项目")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(Color.App.tabBackground.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8]))
                                    .foregroundColor(Color.gray.opacity(0.3))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 110)
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .sheet(isPresented: $showNewProject) {
            NewProjectView()
        }
        .sheet(isPresented: $showManage) {
            ProjectManageView()
                .environmentObject(store)
        }
    }
    
    @ViewBuilder
    private func tabButton(label: String, idx: Int) -> some View {
        Button(action: { selectedTab = idx }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(selectedTab == idx ? Color.App.darkGreen : Color.App.textBlack.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTab == idx ? Color.App.primaryGreen : Color.clear)
                .clipShape(Capsule())
        }
    }
}

// MARK: - 项目卡片（大版，含详情按钮）
struct ProjectDetailCard: View {
    let project: Project
    
    // 进度条百分比预警色（超支用红，接近满用橙）
    private var progressPctColor: Color {
        let p = project.budgetProgress
        if p >= 1.0 { return Color.App.redExpense }
        if p >= 0.8 { return Color(hex: "#FFA500") }
        return progressEndColor
    }
    
    // 进度条渐变：同色系，从浅到深，不跨色系（避免颜色"脏"）
    private var progressStartColor: Color {
        Color(hex: progressColorPair(for: project.colorHex).start)
    }
    private var progressEndColor: Color {
        Color(hex: progressColorPair(for: project.colorHex).end)
    }
    
    // 按钮背景色 = 项目主题色，文字色 = 对应深色
    private var buttonBgColor: Color { Color(hex: project.colorHex) }
    private var buttonFgColor: Color {
        Color(hex: progressColorPair(for: project.colorHex).end)
    }
    
    // 标签样式：进行中=绿，已归档=黄
    private var tagBg: Color {
        project.isArchived ? Color.App.lightYellow : Color.App.primaryGreen.opacity(0.5)
    }
    private var tagFg: Color {
        project.isArchived ? Color.App.darkYellow : Color.App.darkGreen
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.App.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 4)
            
            // 装饰模糊圆
            Circle()
                .fill(Color(hex: project.colorHex).opacity(0.45))
                .frame(width: 120)
                .blur(radius: 28)
                .offset(x: 100, y: -80)
            
            VStack(alignment: .leading, spacing: 18) {
                // 标题行
                HStack(alignment: .top) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: project.colorHex).opacity(0.4))
                            .frame(width: 48, height: 48)
                            .overlay(
                                AppIconView(name: project.icon, size: 22,
                                            color: Color.App.projectIconColor(for: project.colorHex))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                            Text("创建于 \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text(project.isArchived ? "已归档" : "进行中")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tagFg)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(tagBg)
                        .clipShape(Capsule())
                }
                
                if !project.desc.isEmpty {
                    Text(project.desc)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .lineLimit(2)
                }
                
                // 预算进度
                if project.budget > 0 {
                    VStack(spacing: 8) {
                        HStack {
                            Text("预算进度")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(project.budgetProgress * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(progressPctColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // 轨道：干净浅灰
                                Capsule()
                                    .fill(Color.App.progressTrack)
                                    .frame(height: 10)
                                // 填充：同色系渐变
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [progressStartColor, progressEndColor],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * project.budgetProgress)), height: 10)
                            }
                        }
                        .frame(height: 10)
                        HStack {
                            Text("已用: ¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                            Spacer()
                            Text("预算: ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    }
                } else {
                    Text("总支出: ¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                // 查看详情按钮：使用项目自己的颜色（对标原型）
                HStack {
                    Text("查看详情")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(project.isArchived ? Color.App.darkYellow : buttonFgColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(project.isArchived ? Color.App.lightYellow : buttonBgColor)
                .clipShape(Capsule())
            }
            .padding(24)
        }
    }
}

// MARK: - 进度条同色系色对（对标 React 原型色号）
struct ProgressColorPair {
    let start: String  // 渐变起点（浅色）
    let end: String    // 渐变终点（深色）
}

func progressColorPair(for colorHex: String) -> ProgressColorPair {
    switch colorHex.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")) {
    case "A8E6CF", "DCEDC1", "A8E0C2":
        return ProgressColorPair(start: "#A8E6CF", end: "#2C6956")
    case "B3D1E6":
        return ProgressColorPair(start: "#B3D1E6", end: "#2E6A8A")
    case "FDD1B4", "F6D7A8":
        return ProgressColorPair(start: "#F6D7A8", end: "#8A5A1E")
    case "F2B7C6":
        return ProgressColorPair(start: "#F2B7C6", end: "#8A3A52")
    case "D8C6E8":
        return ProgressColorPair(start: "#D8C6E8", end: "#5A3A7A")
    case "BFE6EA":
        return ProgressColorPair(start: "#BFE6EA", end: "#2A7A82")
    case "C8E6C9":
        return ProgressColorPair(start: "#C8E6C9", end: "#2E6E30")
    case "DCCFC4":
        return ProgressColorPair(start: "#DCCFC4", end: "#7A5A3E")
    case "DCDE8D":
        return ProgressColorPair(start: "#DCDE8D", end: "#5F621F")
    case "DBEAFE":
        return ProgressColorPair(start: "#BFDBFE", end: "#1D4ED8")
    case "F3E8FF":
        return ProgressColorPair(start: "#E9D5FF", end: "#7C3AED")
    case "FFEDD5":
        return ProgressColorPair(start: "#FED7AA", end: "#C2410C")
    case "FCE7F3":
        return ProgressColorPair(start: "#FBCFE8", end: "#BE185D")
    default:
        return ProgressColorPair(start: "#A8E6CF", end: "#2C6956")
    }
}

#Preview {
    NavigationView {
        ProjectsView()
            .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
    }
}
