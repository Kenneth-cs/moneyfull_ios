import SwiftUI
import SwiftData

struct ProjectManageView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editingProject: Project? = nil
    
    // 分组：置顶 & 其他（从 activeProjects 中拆分，保持原有排序）
    private var pinnedProjects: [Project] {
        store.activeProjects.filter { $0.isPinned }
    }
    
    private var otherProjects: [Project] {
        store.activeProjects.filter { !$0.isPinned }
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: 置顶项目
                Section(header: Text("置顶项目")) {
                    ForEach(pinnedProjects) { project in
                        ProjectManageRow(project: project)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingProject = project
                            }
                    }
                    .onMove { source, destination in
                        moveProjects(source: source, destination: destination, isPinned: true)
                    }
                }
                
                // MARK: 其他项目
                if !otherProjects.isEmpty {
                    Section(header: Text("其他项目")) {
                        ForEach(otherProjects) { project in
                            ProjectManageRow(project: project)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingProject = project
                                }
                        }
                        .onMove { source, destination in
                            moveProjects(source: source, destination: destination, isPinned: false)
                        }
                    }
                }
                
                // MARK: 提示
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            Text("长按拖拽可调整项目排序")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("项目管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .sheet(item: $editingProject) { project in
                EditProjectView(project: project)
                    .environmentObject(store)
                    .environmentObject(storeManager)
            }
        }
    }
    
    // MARK: - 拖拽排序
    private func moveProjects(source: IndexSet, destination: Int, isPinned: Bool) {
        var projects = isPinned ? pinnedProjects : otherProjects
        projects.move(fromOffsets: source, toOffset: destination)
        store.updateProjectSortOrder(projects)
    }
}

// MARK: - 项目管理行视图
struct ProjectManageRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 14) {
            // 项目图标
            Circle()
                .fill(Color(hex: project.colorHex).opacity(0.45))
                .frame(width: 40, height: 40)
                .overlay(
                    AppIconView(name: project.icon, size: 18,
                                color: Color.App.projectIconColor(for: project.colorHex))
                )
            
            // 项目名称
            Text(project.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.App.textBlack)
            
            Spacer()
            
            // 预算信息
            if project.budget > 0 {
                Text("预算: ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("未设预算")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            // 编辑指示
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectManageView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
