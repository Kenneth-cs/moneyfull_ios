import SwiftUI
import SwiftData
struct EditProjectView: View {
    let project: Project
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    @State private var name: String
    @State private var desc: String
    @State private var budgetText: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    
    @State private var showDeleteConfirm = false
    
    private let iconOptions = CategoryIconLibrary.project
    
    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _desc = State(initialValue: project.desc)
        _budgetText = State(initialValue: project.budget > 0 ? String(format: "%.0f", project.budget) : "")
        _selectedIcon = State(initialValue: project.icon)
        _selectedColor = State(initialValue: project.colorHex)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: 项目名称
                    VStack(alignment: .leading, spacing: 10) {
                        Text("项目名称").sectionTitle()
                        TextField("输入项目名称", text: $name)
                            .textFieldStyle()
                    }
                    
                    // MARK: 项目描述
                    VStack(alignment: .leading, spacing: 10) {
                        Text("项目描述（选填）").sectionTitle()
                        TextField("简单介绍一下这个项目...", text: $desc)
                            .textFieldStyle()
                    }
                    
                    // MARK: 预算
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预算金额（选填，0=不限预算）").sectionTitle()
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                            TextField("0", text: $budgetText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(16)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // MARK: 图标选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择图标").sectionTitle()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Circle()
                                        .fill(Color(hex: selectedColor).opacity(0.55))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: icon)
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.App.projectIconColor(for: selectedColor))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedIcon == icon ? 3 : 0)
                                        )
                                }
                            }
                        }
                    }
                    
                    // MARK: 颜色选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择颜色").sectionTitle()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(Color.App.Morandi.allHexes, id: \.self) { hex in
                                Button(action: {
                                    selectedColor = hex
                                }) {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedColor == hex ? 3 : 0)
                                                .padding(2)
                                        )
                                }
                            }
                        }
                    }
                    
                    // MARK: 预览
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预览").sectionTitle()
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: selectedColor).opacity(0.55))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(Color.App.projectIconColor(for: selectedColor))
                                        .font(.system(size: 22))
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name.isEmpty ? "项目名称" : name)
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
                                if !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                    }
                    
                    // MARK: 操作按钮
                    VStack(spacing: 12) {
                        Button {
                            store.toggleArchive(project: project)
                        } label: {
                            Text(project.isArchived ? "取消归档" : "归档项目")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(project.isArchived ? Color.App.darkGreen : Color.App.darkOrange)
                                .background(project.isArchived ? Color.App.primaryGreen.opacity(0.3) : Color.App.lightOrange.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("删除项目")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(Color.App.redExpense)
                                .background(Color.App.redExpense.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(24)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let budget = Double(budgetText) ?? 0
                        store.updateProject(project, name: name, icon: selectedIcon,
                                            colorHex: selectedColor, desc: desc, budget: budget)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("确认删除该项目？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    store.deleteProject(project)
                    presentationMode.wrappedValue.dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后项目内所有账单将被一并清除，且无法恢复。")
            }
        }
    }
}

#Preview {
    NavigationView {
        EditProjectView(project: Project(name: "预览项目", icon: "folder.fill", colorHex: "#A8E0C2", desc: "这是一个示例", budget: 1000))
            .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
    }
}
