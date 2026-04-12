import SwiftUI
import SwiftData
struct NewProjectView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    @State private var name = ""
    @State private var desc = ""
    @State private var budgetText = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "#A8E6CF"
    
    private let iconOptions = [
        ("folder.fill", "#A8E6CF"), ("house.fill", "#DCEDC1"), ("airplane", "#A8E6CF"),
        ("car.fill", "#DCDE8D"), ("cart.fill", "#FDD1B4"), ("briefcase.fill", "#FDD1B4"),
        ("heart.fill", "#FCE7F3"), ("book.fill", "#DBEAFE"), ("gamecontroller.fill", "#F3E8FF"),
        ("paintpalette.fill", "#FDD1B4"), ("hammer.fill", "#DCEDC1"), ("graduationcap.fill", "#FFEDD5"),
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: 项目名称
                    VStack(alignment: .leading, spacing: 10) {
                        Text("项目名称").sectionTitle()
                        TextField("例如：新疆之旅、海景房装修...", text: $name)
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
                    
                    // MARK: 图标 + 颜色选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择图标").sectionTitle()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(iconOptions, id: \.0) { (icon, color) in
                                Button(action: {
                                    selectedIcon = icon
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(Color(hex: color).opacity(0.3))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: icon)
                                                .font(.system(size: 22))
                                                .foregroundColor(Color(hex: color))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedIcon == icon ? 3 : 0)
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
                                .fill(Color(hex: selectedColor).opacity(0.25))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(Color(hex: selectedColor))
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
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(24)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let budget = Double(budgetText) ?? 0
                        store.addProject(name: name, icon: selectedIcon, colorHex: selectedColor,
                                        desc: desc, budget: budget)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - 便捷 View Modifier 扩展
extension View {
    func textFieldStyle() -> some View {
        self
            .padding(16)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .font(.system(size: 16))
    }
}

extension Text {
    func sectionTitle() -> some View {
        self
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Color.App.textBlack.opacity(0.7))
    }
}

#Preview {
    NewProjectView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
