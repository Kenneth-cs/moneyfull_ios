import SwiftUI
import SwiftData

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0
    @State private var showNewProject = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                PageHeader(title: "项目中心")
                
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
                            Text("慢慢规划，不着急，\n我在这儿陪你。")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectDetailCard(project: project)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 新建项目按钮（仅进行中 tab 显示）
                    if selectedTab == 0 {
                        Button(action: { showNewProject = true }) {
                            VStack(spacing: 14) {
                                Circle()
                                    .fill(Color.white)
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
    
    private var progressColor: Color {
        let p = project.budgetProgress
        if p >= 1.0 { return Color.App.redExpense }
        if p >= 0.8 { return Color(hex: "#FFA500") }
        return Color.App.darkGreen
    }
    
    // 标签样式：进行中=绿，已归档=黄，和设计稿一致
    private var tagBg: Color {
        project.isArchived ? Color.App.lightYellow : Color.App.primaryGreen.opacity(0.5)
    }
    private var tagFg: Color {
        project.isArchived ? Color.App.darkYellow : Color.App.darkGreen
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 4)
            
            // 装饰模糊圆（透明度提高，更有存在感）
            Circle()
                .fill(Color(hex: project.colorHex).opacity(0.45))
                .frame(width: 120)
                .blur(radius: 28)
                .offset(x: 100, y: -80)
            
            VStack(alignment: .leading, spacing: 18) {
                // 标题行
                HStack(alignment: .top) {
                    HStack(spacing: 14) {
                        // 图标圆圈：透明度从 0.25 → 0.4，更清晰
                        Circle()
                            .fill(Color(hex: project.colorHex).opacity(0.4))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: project.icon)
                                    .foregroundColor(Color(hex: project.colorHex))
                                    .font(.system(size: 20, weight: .semibold))
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
                    // 标签：进行中用绿色（对标设计稿），已归档用黄色
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
                                .foregroundColor(progressColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // 轨道：暖灰色，和设计稿一致
                                Capsule()
                                    .fill(Color(hex: "#E8E0D8"))
                                    .frame(height: 10)
                                // 填充：饱和渐变，从项目色到深绿
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: project.colorHex), progressColor],
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
                
                // 查看详情按钮：实心绿色，和设计稿一致
                HStack {
                    Text("查看详情")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(project.isArchived ? Color.App.darkYellow : Color.App.darkGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(project.isArchived ? Color.App.lightYellow : Color.App.primaryGreen)
                .clipShape(Capsule())
            }
            .padding(24)
        }
    }
}

#Preview {
    NavigationView {
        ProjectsView()
            .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
    }
}
