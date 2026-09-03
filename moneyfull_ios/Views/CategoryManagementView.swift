import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showAddSheet = false
    @State private var editingCategory: Category?
    @State private var confirmDeleteCategory: Category?

    private let iconOptions = CategoryIconLibrary.all
    
    // 按 groupName 分组的分类数据
    private var groupedCategories: [(groupName: String, categories: [Category])] {
        let allCats = store.categories
        
        // 核心预设分组顺序
        let coreGroups = ["吃喝", "居家", "出行", "娱乐", "成长", "人情", "其他", "工资", "额外", "临时"]
        
        // 按 groupName 分组
        var groups = [String: [Category]]()
        for cat in allCats {
            let group = cat.groupName.isEmpty ? "其他" : cat.groupName
            groups[group, default: []].append(cat)
        }
        
        // 排序：核心分组按顺序，自定义分组按字母排序
        let coreResult = coreGroups.compactMap { group -> (groupName: String, categories: [Category])? in
            guard let cats = groups[group], !cats.isEmpty else { return nil }
            return (groupName: group, categories: cats.sorted { $0.createdAt < $1.createdAt })
        }
        
        let customGroups = groups.keys.filter { !coreGroups.contains($0) }.sorted()
        let customResult = customGroups.compactMap { group -> (groupName: String, categories: [Category])? in
            guard let cats = groups[group], !cats.isEmpty else { return nil }
            return (groupName: group, categories: cats.sorted { $0.createdAt < $1.createdAt })
        }
        
        return coreResult + customResult
    }

    var body: some View {
        NavigationView {
            List {
                // 添加自定义分类按钮（第一行）
                Section {
                    Button(action: { showAddSheet = true }) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.App.primaryGreen.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(Color.App.darkGreen)
                                        .font(.system(size: 16, weight: .bold))
                                )
                            Text("添加自定义分类")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(groupedCategories, id: \.groupName) { group in
                    Section {
                        ForEach(group.categories, id: \.id) { cat in
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color(hex: cat.colorHex))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: cat.icon)
                                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                                            .font(.system(size: 16))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.App.textBlack)
                                    if !cat.isGlobal {
                                        Text("自定义")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                
                                // 编辑和删除按钮
                                HStack(spacing: 12) {
                                    Button {
                                        editingCategory = cat
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.App.darkGreen)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(role: .destructive) {
                                        confirmDeleteCategory = cat
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.App.redExpense)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(group.groupName)
                    }
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .alert("确认删除", isPresented: Binding(
                get: { confirmDeleteCategory != nil },
                set: { if !$0 { confirmDeleteCategory = nil } }
            )) {
                Button("取消", role: .cancel) { confirmDeleteCategory = nil }
                Button("删除", role: .destructive) {
                    if let cat = confirmDeleteCategory {
                        store.deleteCategory(cat)
                    }
                    confirmDeleteCategory = nil
                }
            } message: {
                if let cat = confirmDeleteCategory {
                    Text("确定要删除「\(cat.name)」吗？删除后可在此重新添加。")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryFormSheet(
                iconOptions: iconOptions,
                editingCategory: nil,
                allCategories: store.categories,
                onSave: { name, icon, colorHex, groupName in
                    store.addCategory(name: name, icon: icon, colorHex: colorHex, groupName: groupName)
                }
            )
        }
        .sheet(item: $editingCategory) { cat in
            CategoryFormSheet(
                iconOptions: iconOptions,
                editingCategory: cat,
                allCategories: store.categories,
                onSave: { name, icon, colorHex, groupName in
                    store.updateCategory(cat, name: name, icon: icon, colorHex: colorHex, groupName: groupName)
                }
            )
        }
    }
}

struct CategoryFormSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let iconOptions: [String]
    let editingCategory: Category?
    let allCategories: [Category]
    let onSave: (String, String, String, String) -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var selectedGroupName: String
    @State private var showCustomGroupInput: Bool
    @State private var customGroupName: String

    // 核心预设分组
    private let coreGroups = ["吃喝", "居家", "出行", "娱乐", "成长", "人情", "其他", "工资", "额外", "临时"]

    init(iconOptions: [String], editingCategory: Category?, allCategories: [Category], onSave: @escaping (String, String, String, String) -> Void) {
        self.iconOptions = iconOptions
        self.editingCategory = editingCategory
        self.allCategories = allCategories
        self.onSave = onSave
        _name = State(initialValue: editingCategory?.name ?? "")
        _selectedIcon = State(initialValue: editingCategory?.icon ?? "fork.knife")
        _selectedColor = State(initialValue: editingCategory?.colorHex ?? "#A8E0C2")
        
        let initialGroup = editingCategory?.groupName ?? ""
        _selectedGroupName = State(initialValue: initialGroup.isEmpty ? "其他" : initialGroup)
        _showCustomGroupInput = State(initialValue: false)
        _customGroupName = State(initialValue: "")
    }
    
    // 动态获取所有已存在的分组名
    private var existingGroupNames: [String] {
        let allGroups = Set(allCategories.compactMap { cat -> String? in
            return cat.groupName.isEmpty ? nil : cat.groupName
        })
        return Array(allGroups).sorted()
    }
    
    // 获取所有可用分组（核心 + 动态）
    private var availableGroups: [String] {
        let dynamic = existingGroupNames.filter { !coreGroups.contains($0) }
        return coreGroups + dynamic.sorted()
    }

    private var isEditing: Bool { editingCategory != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("分类名称")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                        TextField("输入分类名称", text: $name)
                            .padding(16)
                            .background(Color.App.tabBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .font(.system(size: 16))
                    }

                    // 所属分组选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("所属分组")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                        
                        if showCustomGroupInput {
                            HStack {
                                TextField("输入新分组名称", text: $customGroupName)
                                    .padding(16)
                                    .background(Color.App.tabBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .font(.system(size: 16))
                                
                                Button(action: {
                                    showCustomGroupInput = false
                                    customGroupName = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 20))
                                }
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    // 自定义新分组按钮（放在最前面）
                                    Button(action: {
                                        showCustomGroupInput = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12))
                                            Text("自定义")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(Color.App.darkGreen)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.App.primaryGreen.opacity(0.2))
                                        .clipShape(Capsule())
                                    }
                                    
                                    ForEach(availableGroups, id: \.self) { group in
                                        Button(action: {
                                            selectedGroupName = group
                                        }) {
                                            Text(group)
                                                .font(.system(size: 14, weight: selectedGroupName == group ? .bold : .medium))
                                                .foregroundColor(selectedGroupName == group ? Color.App.darkGreen : .gray)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedGroupName == group ? Color.App.primaryGreen.opacity(0.3) : Color.App.tabBackground)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择图标")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.5) : Color.App.tabBackground)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(Color.App.textBlack.opacity(0.7))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedIcon == icon ? 2.5 : 0)
                                        )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择颜色")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(Color.App.morandiColorOptions, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedColor == color ? 3 : 0)
                                                .padding(2)
                                        )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("预览")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: selectedColor))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(Color.App.textBlack.opacity(0.7))
                                        .font(.system(size: 22))
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name.isEmpty ? "分类名称" : name)
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
                                Text("分组: \(showCustomGroupInput ? (customGroupName.isEmpty ? "新分组" : customGroupName) : selectedGroupName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(24)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle(isEditing ? "编辑分类" : "添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let finalGroupName = showCustomGroupInput ? customGroupName.trimmingCharacters(in: .whitespaces) : selectedGroupName
                        onSave(trimmed, selectedIcon, selectedColor, finalGroupName)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CategoryManagementView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
