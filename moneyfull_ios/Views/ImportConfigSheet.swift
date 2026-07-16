import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    @State private var step: ImportStep = .selectSource
    @State private var selectedSource: ImportSource = .alipay
    @State private var parsedRows: [[String]]?   // CSV 和 xlsx 统一转换成这个二维数组结构
    @State private var fileName: String = ""
    @State private var showFilePicker = false
    @State private var customMapping: [Int: CSVColumn] = [:]
    @State private var previewHeaders: [String] = []
    @State private var previewRows: [[String]] = []
    @State private var detectedMapping: [Int: CSVColumn] = [:]
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum ImportStep {
        case selectSource
        case preview
        case result
    }
    
    struct ImportResult {
        let count: Int
        let batchID: UUID
        let projectName: String
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case .selectSource:
                        sourceSelectionView
                    case .preview:
                        previewView
                    case .result:
                        resultView
                    }
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType.commaSeparatedText,
                UTType.plainText,
                UTType(filenameExtension: "xlsx") ?? UTType.data,  // 微信支付账单导出的是 xlsx 格式
                UTType.data
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("导入失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var sourceSelectionView: some View {
        VStack(spacing: 24) {
            headerSection
            
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(icon: "app.fill", title: "选择来源 App")
                
                VStack(spacing: 12) {
                    ForEach(ImportSource.allCases, id: \.self) { source in
                        sourceOption(source)
                    }
                }
            }
            .padding(20)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue.opacity(0.6))
                    Text("导入须知")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    infoRow("导入的数据将暂存于「历史账单」项目")
                    infoRow("支持后续使用 AI 整理功能分配到具体项目")
                    infoRow("支持撤销整批导入操作")
                }
            }
            .padding(16)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("选择 CSV 文件")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.App.darkGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    private func sourceOption(_ source: ImportSource) -> some View {
        let iconColor = Color(hex: source.iconColor)
        let isSelected = selectedSource == source

        return Button {
            selectedSource = source
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.App.primaryGreen : .gray.opacity(0.4))

                Image(systemName: source.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.App.textBlack)
                    // 支付宝/微信给个说明，降低用户困惑
                    if source == .alipay {
                        Text("支付宝 App → 我的 → 账单 → 下载账单")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    } else if source == .wechat {
                        Text("微信 → 支付 → 钱包 → 账单 → 下载账单")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private var previewView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(Color.App.primaryGreen)
                
                Text("数据预览")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                
                Text(fileName)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "tablecells", title: "前 3 行数据")
                
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            ForEach(Array(previewHeaders.enumerated()), id: \.offset) { index, header in
                                Text(header)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                        }
                        
                        Divider()
                        
                        ForEach(Array(previewRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                                    Text(cell)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.App.textBlack)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "arrow.triangle.branch", title: "列映射")
                
                VStack(spacing: 8) {
                    ForEach(Array(detectedMapping.sorted(by: { $0.key < $1.key })), id: \.key) { index, column in
                        if index < previewHeaders.count {
                            HStack {
                                Text(previewHeaders[index])
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(width: 100, alignment: .leading)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text(column.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(column == .ignore ? .gray : Color.App.darkGreen)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            HStack(spacing: 16) {
                Button {
                    step = .selectSource
                    parsedRows = nil
                } label: {
                    Text("返回")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    performImport()
                } label: {
                    HStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isImporting ? "导入中..." : "确认导入")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.App.darkGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isImporting)
            }
        }
    }
    
    private var resultView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color.App.darkGreen)
                
                Text("导入成功")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                
                VStack(spacing: 8) {
                    Text("已导入 \(importResult?.count ?? 0) 条记录")
                        .font(.system(size: 16, weight: .medium))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                        Text("暂存于「历史账单」项目")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                }
            }
            .padding(.top, 40)
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("提示")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text("导入的历史数据可以使用 AI 整理功能，智能分配到对应项目中")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color.yellow.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.App.darkGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button {
                    undoLastImport()
                } label: {
                    Text("撤销本次导入")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(Color.App.primaryGreen)
            
            Text("导入账单")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            Text("支持支付宝、微信及主流记账 App")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
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
    
    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let data = try Data(contentsOf: url)
                let isXLSX = url.pathExtension.lowercased() == "xlsx"

                let rows: [[String]]
                if isXLSX {
                    // 微信支付账单导出的是 xlsx（Excel 格式，本质是 ZIP+XML），
                    // 不能当文本解码，要走专门的 xlsx 读取器
                    guard let xlsxRows = XLSXReader.parseFirstSheetRows(data: data) else {
                        errorMessage = "无法解析该 xlsx 文件，请确认是从微信支付导出的原始账单文件"
                        showError = true
                        return
                    }
                    rows = xlsxRows
                } else {
                    let content: String
                    if let string = String(data: data, encoding: .utf8) {
                        content = string
                    } else if let string = String(data: data, encoding: .shiftJIS) {
                        content = string
                    } else if let string = String(data: data, encoding: .isoLatin1) {
                        content = string
                    } else {
                        errorMessage = "无法识别文件编码，请确保是 UTF-8 编码的 CSV 文件"
                        showError = true
                        return
                    }
                    rows = CSVImportService.parseCSV(content: content)
                }

                parsedRows = rows
                fileName = url.lastPathComponent

                let preview = CSVImportService.previewData(
                    rows: rows,
                    source: selectedSource
                )
                previewHeaders = preview.headers
                previewRows = preview.rows
                detectedMapping = preview.mapping
                
                if selectedSource == .custom {
                    customMapping = detectedMapping
                }
                
                step = .preview
            } catch {
                errorMessage = "读取文件失败：\(error.localizedDescription)"
                showError = true
            }
            
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"
            showError = true
        }
    }
    
    private func performImport() {
        guard let rows = parsedRows else { return }
        isImporting = true

        // 必须在主线程提前捕获所有 @State 数据，再进入后台线程
        // 注意：selectedSource / customMapping 都是 @State，不能在 DispatchQueue.global 里直接访问
        //
        // 注意：分类支持"项目专属"（Category.projectID），不同项目可能存在同名分类
        // （比如两个项目都有"其它"分类），用 uniqueKeysWithValues 一旦撞名就会直接 crash！
        // 改用 uniquingKeysWith，遇到重复名字时保留先出现的那个即可
        let categoryLookup = Dictionary(
            store.categories.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let source = selectedSource
        let mapping: [Int: CSVColumn]? = (selectedSource == .custom) ? customMapping : nil

        DispatchQueue.global(qos: .userInitiated).async {

            let parsed = CSVImportService.importTransactions(
                rows: rows,
                source: source,
                customMapping: mapping,
                categoryLookup: categoryLookup
            )
            
            DispatchQueue.main.async {
                guard !parsed.isEmpty else {
                    isImporting = false
                    errorMessage = "未能解析出有效的账单数据。请确认：\n1. 已选择正确的来源（如「支付宝」）\n2. 文件是从对应 App 导出的 CSV 账单"
                    showError = true
                    return
                }
                
                let batchID = UUID()
                let count = store.addImportedTransactions(
                    parsed.map { ($0.amount, $0.type, $0.categoryName, $0.categoryIcon, $0.categoryColorHex, $0.note, $0.date) },
                    batchID: batchID
                )
                
                importResult = ImportResult(count: count, batchID: batchID, projectName: "历史账单")
                isImporting = false
                step = .result
            }
        }
    }
    
    private func undoLastImport() {
        guard let result = importResult else { return }
        _ = store.undoImport(batchID: result.batchID)
        importResult = nil
        step = .selectSource
        parsedRows = nil
    }
}
