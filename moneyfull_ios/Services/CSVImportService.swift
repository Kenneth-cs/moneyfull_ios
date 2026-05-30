import Foundation
import SwiftData

enum ImportSource: String, CaseIterable {
    case suishouji = "随手记"
    case moze = "MOZE"
    case qianji = "钱迹"
    case moneyMoney = "MoneyMoney"
    case custom = "通用 CSV"
    
    var icon: String {
        switch self {
        case .suishouji: return "book.fill"
        case .moze: return "m.square.fill"
        case .qianji: return "yensign.circle.fill"
        case .moneyMoney: return "dollarsign.circle.fill"
        case .custom: return "doc.text.fill"
        }
    }
}

enum CSVColumn: String, CaseIterable {
    case date = "日期"
    case time = "时间"
    case type = "类型"
    case amount = "金额"
    case category = "分类"
    case subcategory = "子分类"
    case project = "项目"
    case note = "备注"
    case account = "账户"
    case payee = "商家"
    case ignore = "忽略"
}

struct ParsedTransaction {
    let amount: Double
    let type: TransactionType
    let categoryName: String
    let categoryIcon: String
    let categoryColorHex: String
    let note: String
    let date: Date
}

struct CSVImportService {
    
    static func columnMapping(for source: ImportSource) -> [Int: CSVColumn] {
        switch source {
        case .suishouji:
            return [0: .date, 1: .type, 2: .amount, 3: .category, 4: .subcategory, 5: .account, 6: .payee, 7: .project, 8: .note]
        case .moze:
            return [0: .date, 1: .type, 2: .category, 3: .subcategory, 4: .amount, 5: .note, 6: .account]
        case .qianji:
            return [0: .date, 1: .type, 2: .amount, 3: .category, 4: .subcategory, 5: .account, 6: .note]
        case .moneyMoney:
            return [0: .date, 1: .amount, 2: .payee, 3: .category, 4: .note]
        case .custom:
            return [:]
        }
    }
    
    static func detectColumns(from headerRow: [String]) -> [Int: CSVColumn] {
        var mapping: [Int: CSVColumn] = [:]
        
        for (index, header) in headerRow.enumerated() {
            let h = header.lowercased().trimmingCharacters(in: .whitespaces)
            
            if h.contains("日期") || h.contains("date") || h.contains("时间") || h.contains("记账时间") {
                mapping[index] = h.contains("时间") && !h.contains("日期") ? .time : .date
            } else if h.contains("类型") || h.contains("收支") || h.contains("type") {
                mapping[index] = .type
            } else if h.contains("金额") || h.contains("amount") {
                mapping[index] = .amount
            } else if h.contains("一级分类") || h.contains("分类") || h.contains("category") {
                mapping[index] = .category
            } else if h.contains("二级分类") || h.contains("子分类") || h.contains("subcategory") {
                mapping[index] = .subcategory
            } else if h.contains("项目") || h.contains("project") {
                mapping[index] = .project
            } else if h.contains("备注") || h.contains("note") || h.contains("memo") {
                mapping[index] = .note
            } else if h.contains("账户") || h.contains("account") {
                mapping[index] = .account
            } else if h.contains("商家") || h.contains("payee") || h.contains("merchant") {
                mapping[index] = .payee
            } else {
                mapping[index] = .ignore
            }
        }
        
        return mapping
    }
    
    static func parseCSV(content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        
        let cleanContent = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        
        for char in cleanContent {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if !currentField.isEmpty || !currentRow.isEmpty {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    if currentRow.contains(where: { !$0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                }
            } else {
                currentField.append(char)
            }
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            if currentRow.contains(where: { !$0.isEmpty }) {
                rows.append(currentRow)
            }
        }
        
        return rows
    }
    
    static func importTransactions(
        from csvContent: String,
        source: ImportSource,
        customMapping: [Int: CSVColumn]? = nil,
        categoryLookup: [String: Category]
    ) -> [ParsedTransaction] {
        let rows = parseCSV(content: csvContent)
        guard rows.count > 1 else { return [] }
        
        let hasHeader = source != .custom || customMapping == nil
        let mapping: [Int: CSVColumn]
        
        if let custom = customMapping {
            mapping = custom
        } else if source == .custom {
            mapping = detectColumns(from: rows[0])
        } else {
            mapping = columnMapping(for: source)
        }
        
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        
        var transactions: [ParsedTransaction] = []
        
        for row in dataRows {
            guard let tx = parseRow(row, mapping: mapping, categoryLookup: categoryLookup) else { continue }
            transactions.append(tx)
        }
        
        return transactions
    }
    
    private static func parseRow(_ row: [String], mapping: [Int: CSVColumn], categoryLookup: [String: Category]) -> ParsedTransaction? {
        var dateStr = ""
        var timeStr = ""
        var typeStr = ""
        var amountStr = ""
        var categoryStr = ""
        var subcategoryStr = ""
        var noteStr = ""
        
        for (index, column) in mapping {
            guard index < row.count else { continue }
            let value = row[index]
            
            switch column {
            case .date: dateStr = value
            case .time: timeStr = value
            case .type: typeStr = value
            case .amount: amountStr = value
            case .category: categoryStr = value
            case .subcategory: subcategoryStr = value
            case .note: noteStr = value
            default: break
            }
        }
        
        guard !amountStr.isEmpty else { return nil }
        
        let cleanAmount = amountStr
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        guard let amount = Double(cleanAmount), amount > 0 else { return nil }
        
        let type = parseTransactionType(typeStr, amount: amount)
        
        let date = parseDate(dateStr, timeStr: timeStr) ?? Date()
        
        let categoryName = subcategoryStr.isEmpty ? categoryStr : subcategoryStr
        let finalCategory = categoryName.isEmpty ? "其它" : categoryName
        
        let categoryInfo = categoryLookup[finalCategory]
        let categoryIcon = categoryInfo?.icon ?? "ellipsis.circle.fill"
        let categoryColorHex = categoryInfo?.colorHex ?? "#DCCFC4"
        
        return ParsedTransaction(
            amount: amount,
            type: type,
            categoryName: finalCategory,
            categoryIcon: categoryIcon,
            categoryColorHex: categoryColorHex,
            note: noteStr,
            date: date
        )
    }
    
    private static func parseTransactionType(_ typeStr: String, amount: Double) -> TransactionType {
        let lower = typeStr.lowercased()
        
        if lower.contains("收入") || lower.contains("income") || lower.contains("in") || lower.contains("+") {
            return .income
        }
        if lower.contains("支出") || lower.contains("expense") || lower.contains("out") || lower.contains("-") {
            return .expense
        }
        
        return amount < 0 ? .income : .expense
    }
    
    private static func parseDate(_ dateStr: String, timeStr: String) -> Date? {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd",
            "yyyy年MM月dd日 HH:mm",
            "yyyy年MM月dd日",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy",
            "yyyyMMdd"
        ]
        
        let combined = timeStr.isEmpty ? dateStr : "\(dateStr) \(timeStr)"
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: combined) {
                return date
            }
        }
        
        return nil
    }
    
    static func previewData(from csvContent: String, source: ImportSource, customMapping: [Int: CSVColumn]? = nil) -> (headers: [String], rows: [[String]], mapping: [Int: CSVColumn]) {
        let rows = parseCSV(content: csvContent)
        guard !rows.isEmpty else { return ([], [], [:]) }
        
        let mapping: [Int: CSVColumn]
        if let custom = customMapping {
            mapping = custom
        } else if source == .custom {
            mapping = detectColumns(from: rows[0])
        } else {
            mapping = columnMapping(for: source)
        }
        
        let headers = rows[0]
        let previewRows = Array(rows.dropFirst().prefix(3))
        
        return (headers, previewRows, mapping)
    }
}
