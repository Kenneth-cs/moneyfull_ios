import SwiftUI
import SwiftData

struct CategorySelectionView: View {
    @Binding var selectedCategory: Category?
    var type: TransactionType
    var categories: [Category]
    var onAddTapped: () -> Void
    @Binding var selectedTab: String
    
    // 触觉反馈
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // 动态计算横向 Tab
    private var tabs: [String] {
        // 核心预设分组（保持高频词靠前的原有顺序）
        let coreExpenseGroups = ["吃喝", "居家", "出行", "娱乐", "成长", "人情", "其他"]
        let coreIncomeGroups = ["工资", "额外", "临时", "其他"]
        let coreGroups = type == .expense ? coreExpenseGroups : coreIncomeGroups
        
        // 从分类数据中动态提取所有不为空的 groupName
        let allGroupNames = Set(typeCategories.compactMap { cat -> String? in
            if type == .income && !cat.incomeGroupName.isEmpty {
                return cat.incomeGroupName
            }
            return cat.groupName.isEmpty ? nil : cat.groupName
        })
        
        // 用户自定义的分组（不在核心列表中的）
        let customGroups = allGroupNames.filter { !coreGroups.contains($0) }.sorted()
        
        // 组装最终的 Tab 列表
        var result = ["常用"]
        result.append(contentsOf: coreGroups.filter { allGroupNames.contains($0) })
        result.append(contentsOf: customGroups)
        result.append("全部")
        
        return result
    }
    
    // 过滤出当前交易类型的分类
    private var typeCategories: [Category] {
        categories.filter {
            type == .expense ? ($0.transactionType == "expense" || $0.transactionType == "both")
                             : ($0.transactionType == "income" || $0.transactionType == "both")
        }
    }
    
    // 获取指定分类在当前类型下的实际分组名
    private func groupName(for cat: Category) -> String {
        if type == .income && !cat.incomeGroupName.isEmpty {
            return cat.incomeGroupName
        }
        let group = cat.groupName
        return group.isEmpty ? "其他" : group
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: 标题和横向 Tab
            VStack(alignment: .leading, spacing: 12) {
                Text("分类")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                    .padding(.horizontal, 24)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(tabs, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                    impactFeedback.impactOccurred()
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(tab)
                                        .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                                        .foregroundColor(selectedTab == tab ? Color.App.textBlack : Color.gray)
                                    
                                    // 底部指示器
                                    Capsule()
                                        .fill(selectedTab == tab ? Color.App.primaryGreen : Color.clear)
                                        .frame(height: 3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // 内容区域
            if selectedTab == "常用" {
                // 常用面板
                let frequentCats = typeCategories.filter { $0.useCount > 0 }
                    .sorted {
                        if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
                        return ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast)
                    }
                    .prefix(11) // 最多展示 11 个，留一个给新增
                
                categoryGrid(cats: Array(frequentCats), showAdd: true)
                
            } else if selectedTab == "全部" {
                // 全部面板，按分组显示
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        let groups = tabs.filter { $0 != "常用" && $0 != "全部" }
                        ForEach(groups, id: \.self) { group in
                            let groupCats = filteredAndSortedCategories(for: group)
                            if !groupCats.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 24)
                                    
                                    categoryGrid(cats: groupCats, showAdd: false, horizontalPadding: 24)
                                }
                            }
                        }
                        
                        // 在最后加一个新增按钮网格
                        categoryGrid(cats: [], showAdd: true, horizontalPadding: 24)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300) // 限制全部视图的高度，避免无限拉长
                
            } else {
                // 具体分组面板
                let cats = filteredAndSortedCategories(for: selectedTab)
                categoryGrid(cats: cats, showAdd: true)
            }
        }
        .onChange(of: type) { _ in
            selectedTab = "常用" // 切换收支时重置 Tab
        }
    }
    
    // 获取特定分组下的分类，并确保该组的“主类”排在第一个
    private func filteredAndSortedCategories(for group: String) -> [Category] {
        let cats = typeCategories.filter { groupName(for: $0) == group }
        
        // 定义每个分组的主类目名称（主类目会固定排在第一位）
        let primaryNames: [String: String] = [
            "吃喝": "餐饮",
            "居家": "居家",
            "出行": "交通",
            "娱乐": "娱乐",
            "成长": "成长",
            "人情": "人情",
            "其他": "其他",
            "工资": "工资",
            "额外": "额外",
            "临时": "临时"
        ]
        
        let primaryName = primaryNames[group]
        
        return cats.sorted {
            let isPrimary0 = $0.name == primaryName || (group == "其他" && $0.name == "其它")
            let isPrimary1 = $1.name == primaryName || (group == "其他" && $1.name == "其它")
            if isPrimary0 != isPrimary1 { return isPrimary0 }
            return $0.createdAt < $1.createdAt
        }
    }
    
    // 渲染网格
    private func categoryGrid(cats: [Category], showAdd: Bool, horizontalPadding: CGFloat = 24) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
            ForEach(cats, id: \.id) { cat in
                CategoryItem(name: cat.name, icon: cat.icon, colorHex: cat.colorHex, isSelected: selectedCategory?.id == cat.id) {
                    impactFeedback.impactOccurred()
                    selectedCategory = cat
                }
            }
            if showAdd {
                Button(action: { onAddTapped() }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.App.primaryGreen.opacity(0.4))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            )
                        Text("新增")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.App.darkGreen.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}
