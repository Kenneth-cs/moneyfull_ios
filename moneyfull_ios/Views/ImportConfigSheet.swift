import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    @State private var step: ImportStep = .selectSource
    @State private var selectedSource: ImportSource = .suishouji
    @State private var csvContent: String?
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
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText, UTType.data],
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
        Button {
            selectedSource = source
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedSource == source ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedSource == source ? Color.App.primaryGreen : .gray.opacity(0.4))
                
                Image(systemName: source.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.darkGreen)
                    .frame(width: 36, height: 36)
                    .background(Color.App.primaryGreen.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(source.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                
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
                    csvContent = nil
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
            
            Text("从其他记账 App 迁移数据到钱小满")
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
                
                var encoding: String.Encoding = .utf8
                if let string = String(data: data, encoding: .utf8) {
                    csvContent = string
                } else if let string = String(data: data, encoding: .shiftJIS) {
                    csvContent = string
                    encoding = .shiftJIS
                } else if let string = String(data: data, encoding: .isoLatin1) {
                    csvContent = string
                    encoding = .isoLatin1
                } else {
                    errorMessage = "无法识别文件编码，请确保是 UTF-8 编码的 CSV 文件"
                    showError = true
                    return
                }
                
                fileName = url.lastPathComponent
                
                let preview = CSVImportService.previewData(
                    from: csvContent!,
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
        guard let content = csvContent else { return }
        
        isImporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let categoryLookup = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.name, $0) })
            
            let parsed = CSVImportService.importTransactions(
                from: content,
                source: selectedSource,
                customMapping: selectedSource == .custom ? customMapping : nil,
                categoryLookup: categoryLookup
            )
            
            DispatchQueue.main.async {
                guard !parsed.isEmpty else {
                    isImporting = false
                    errorMessage = "未能解析出有效的账单数据，请检查文件格式"
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
        let deleted = store.undoImport(batchID: result.batchID)
        importResult = nil
        step = .selectSource
        csvContent = nil
    }
}
