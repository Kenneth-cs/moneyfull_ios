import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showAddSheet = false
    @State private var editingCategory: Category?
    @State private var confirmDeleteCategory: Category?

    private let iconOptions = CategoryIconLibrary.all

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(store.categories.filter { $0.isGlobal }, id: \.id) { cat in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: cat.icon)
                                        .foregroundColor(Color.App.textBlack.opacity(0.7))
                                        .font(.system(size: 16))
                                )
                            Text(cat.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            Text("系统预设")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .leading) {
                            Button {
                                editingCategory = cat
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                confirmDeleteCategory = cat
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("系统预设分类")
                } footer: {
                    Text("左滑可编辑或删除，删除系统预设分类后可在此重新添加。")
                }

                let customCategories = store.categories.filter { !$0.isGlobal }
                Section {
                    ForEach(customCategories, id: \.id) { cat in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: cat.icon)
                                        .foregroundColor(Color.App.textBlack.opacity(0.7))
                                        .font(.system(size: 16))
                                )
                            Text(cat.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .leading) {
                            Button {
                                editingCategory = cat
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteCategory(cat)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("自定义分类")
                } footer: {
                    Text("左滑可编辑或删除自定义分类。")
                }

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
                onSave: { name, icon, colorHex in
                    store.addCategory(name: name, icon: icon, colorHex: colorHex)
                }
            )
        }
        .sheet(item: $editingCategory) { cat in
            CategoryFormSheet(
                iconOptions: iconOptions,
                editingCategory: cat,
                onSave: { name, icon, colorHex in
                    store.updateCategory(cat, name: name, icon: icon, colorHex: colorHex)
                }
            )
        }
    }
}

struct CategoryFormSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let iconOptions: [String]
    let editingCategory: Category?
    let onSave: (String, String, String) -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

    init(iconOptions: [String], editingCategory: Category?, onSave: @escaping (String, String, String) -> Void) {
        self.iconOptions = iconOptions
        self.editingCategory = editingCategory
        self.onSave = onSave
        _name = State(initialValue: editingCategory?.name ?? "")
        _selectedIcon = State(initialValue: editingCategory?.icon ?? "fork.knife")
        _selectedColor = State(initialValue: editingCategory?.colorHex ?? "#A8E0C2")
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
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
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
                        onSave(trimmed, selectedIcon, selectedColor)
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
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
