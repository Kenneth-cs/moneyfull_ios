import SwiftUI
import SwiftData

struct ExportConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    @State private var selectedTimeRange: ExportTimeRange = .all
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var useAllProjects = true
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportCount = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    timeRangeSection
                    projectScopeSection
                    exportInfoSection
                    exportButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("导出失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.App.primaryGreen)
            
            Text("导出账单")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            Text("导出为 CSV 格式，兼容 Excel、Numbers 等表格软件")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar", title: "时间范围")
            
            VStack(spacing: 12) {
                ForEach(ExportTimeRange.allCases, id: \.self) { range in
                    timeRangeOption(range)
                }
            }
            
            if selectedTimeRange == .custom {
                customDatePickers
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func timeRangeOption(_ range: ExportTimeRange) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeRange = range
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedTimeRange == range ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedTimeRange == range ? Color.App.primaryGreen : .gray.opacity(0.4))
                
                Text(range.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                
                Spacer()
                
                Text(rangeDescription(range))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var customDatePickers: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack {
                Text("开始日期")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                DatePicker("", selection: $customStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
            
            HStack {
                Text("结束日期")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                DatePicker("", selection: $customEndDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
        }
        .padding(.top, 8)
    }
    
    private var projectScopeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "folder.fill", title: "导出范围")
            
            VStack(spacing: 12) {
                projectScopeOption(
                    isSelected: useAllProjects,
                    title: "全部项目",
                    subtitle: "\(store.activeProjects.count) 个项目"
                ) {
                    useAllProjects = true
                    selectedProjectIDs.removeAll()
                }
                
                ForEach(store.activeProjects) { project in
                    projectOption(project)
                }
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func projectScopeOption(isSelected: Bool, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.App.primaryGreen : .gray.opacity(0.4))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.App.textBlack)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private func projectOption(_ project: Project) -> some View {
        let isSelected = selectedProjectIDs.contains(project.id)
        let txCount = project.transactions?.count ?? 0
        
        return Button {
            useAllProjects = false
            if isSelected {
                selectedProjectIDs.remove(project.id)
                if selectedProjectIDs.isEmpty {
                    useAllProjects = true
                }
            } else {
                selectedProjectIDs.insert(project.id)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.App.primaryGreen : .gray.opacity(0.4))
                
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 28, height: 28)
                    .overlay(
                        AppIconView(name: project.icon, size: 14, color: Color(hex: project.colorHex))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.App.textBlack)
                    Text("\(txCount) 笔账单")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private var exportInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue.opacity(0.6))
            
            Text("CSV 文件包含：日期、时间、类型、金额、分类、项目、备注、记录方式")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var exportButton: some View {
        Button {
            performExport()
        } label: {
            HStack(spacing: 10) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(isExporting ? "导出中..." : "导出 CSV 文件")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.App.darkGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isExporting)
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.App.primaryGreen)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.App.textBlack)
        }
    }
    
    private func rangeDescription(_ range: ExportTimeRange) -> String {
        let formatter = DateFormatter()
        
        switch range {
        case .thisMonth:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: Date())
        case .thisYear:
            formatter.dateFormat = "yyyy年"
            return formatter.string(from: Date())
        case .all:
            return "所有记录"
        case .custom:
            return "自选日期"
        }
    }
    
    private func performExport() {
        isExporting = true
        // 在主线程提前捕获 @MainActor 数据，再派发到后台线程处理
        let allTransactions = store.fetchAllTransactions()
        // 分类支持"项目专属"（Category.projectID），不同项目可能存在同名分类，
        // uniqueKeysWithValues 遇到重复 key 会直接 crash，改用 uniquingKeysWith 兼容重名
        let categoryLookup: [String: Category] = Dictionary(
            store.categories.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            let projectScope: ExportProjectScope
            if useAllProjects {
                projectScope = .all
            } else if !selectedProjectIDs.isEmpty {
                projectScope = .selected(selectedProjectIDs)
            } else {
                projectScope = .all
            }
            
            let filtered = CSVExportService.filterTransactions(
                allTransactions: allTransactions,
                timeRange: selectedTimeRange,
                customStartDate: customStartDate,
                customEndDate: customEndDate,
                projectScope: projectScope
            )
            
            let csvContent = CSVExportService.generateCSV(
                transactions: filtered,
                categoryLookup: categoryLookup
            )
            
            let fileName = CSVExportService.exportFileName(timeRange: selectedTimeRange)
            
            DispatchQueue.main.async {
                isExporting = false
                
                if filtered.isEmpty {
                    errorMessage = "所选条件下没有找到账单记录"
                    showError = true
                    return
                }
                
                exportCount = filtered.count
                
                if let url = CSVExportService.saveCSVFile(content: csvContent, fileName: fileName) {
                    exportedFileURL = url
                    showShareSheet = true
                } else {
                    errorMessage = "文件保存失败，请重试"
                    showError = true
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
