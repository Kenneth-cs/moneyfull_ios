import SwiftData
import Foundation

enum ExportTimeRange: String, CaseIterable {
    case thisMonth = "本月"
    case thisYear = "本年"
    case all = "全部"
    case custom = "自定义"
}

enum ExportProjectScope {
    case all
    case selected(Set<UUID>)
}

struct CSVExportService {
    
    static func generateCSV(
        transactions: [Transaction],
        categoryLookup: [String: Category]? = nil
    ) -> String {
        let bom = "\u{FEFF}"
        let header = "日期,时间,类型,金额,一级分类,分类,项目,备注,记录方式"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        var rows: [String] = []
        
        let sorted = transactions.sorted { $0.date > $1.date }
        
        for tx in sorted {
            let date = dateFormatter.string(from: tx.date)
            let time = timeFormatter.string(from: tx.date)
            let type = tx.type == .expense ? "支出" : "收入"
            let amount = String(format: "%.2f", tx.amount)
            
            let groupName: String
            if let lookup = categoryLookup,
               let category = lookup[tx.categoryName] {
                groupName = tx.type == .expense ? category.groupName : (category.incomeGroupName.isEmpty ? category.groupName : category.incomeGroupName)
            } else {
                groupName = tx.categoryName
            }
            
            let category = tx.categoryName
            let project = tx.project?.name ?? "日常"
            let note = escapeCSVField(tx.note)
            let source = sourceDisplayName(tx.source)
            
            let row = "\(date),\(time),\(type),\(amount),\(escapeCSVField(groupName)),\(escapeCSVField(category)),\(escapeCSVField(project)),\(note),\(source)"
            rows.append(row)
        }
        
        return bom + header + "\n" + rows.joined(separator: "\n")
    }
    
    static func saveCSVFile(content: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("CSV导出失败: \(error)")
            return nil
        }
    }
    
    static func filterTransactions(
        allTransactions: [Transaction],
        timeRange: ExportTimeRange,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        projectScope: ExportProjectScope = .all
    ) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        var startDate: Date?
        var endDate: Date?
        
        switch timeRange {
        case .thisMonth:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate!)
        case .thisYear:
            startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))
            endDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now) + 1, month: 1, day: 1))
        case .custom:
            startDate = customStartDate
            endDate = customEndDate
        case .all:
            break
        }
        
        var filtered = allTransactions
        
        if let start = startDate {
            filtered = filtered.filter { $0.date >= start }
        }
        if let end = endDate {
            filtered = filtered.filter { $0.date < end }
        }
        
        switch projectScope {
        case .all:
            break
        case .selected(let projectIDs):
            filtered = filtered.filter { tx in
                guard let pid = tx.project?.id else { return false }
                return projectIDs.contains(pid)
            }
        }
        
        return filtered
    }
    
    static func exportFileName(timeRange: ExportTimeRange) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        
        let rangeStr: String
        switch timeRange {
        case .thisMonth:
            let mf = DateFormatter()
            mf.dateFormat = "yyyy年MM月"
            rangeStr = mf.string(from: Date())
        case .thisYear:
            let yf = DateFormatter()
            yf.dateFormat = "yyyy年"
            rangeStr = yf.string(from: Date())
        case .all:
            rangeStr = "全部"
        case .custom:
            rangeStr = "自定义"
        }
        
        return "钱小满账单_\(rangeStr)_\(dateStr).csv"
    }
    
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    private static func sourceDisplayName(_ source: TransactionSource) -> String {
        switch source {
        case .manual: return "手动"
        case .voice: return "语音"
        case .image: return "图片"
        case .auto: return "自动"
        }
    }
}
