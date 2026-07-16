import Foundation
import SwiftData

enum ImportSource: String, CaseIterable {
    case alipay = "支付宝"
    case wechat = "微信支付"
    case suishouji = "随手记"
    case moze = "MOZE"
    case qianji = "钱迹"
    case moneyMoney = "MoneyMoney"
    case custom = "通用 CSV"

    var icon: String {
        switch self {
        case .alipay:      return "a.circle.fill"
        case .wechat:      return "message.circle.fill"
        case .suishouji:   return "book.fill"
        case .moze:        return "m.square.fill"
        case .qianji:      return "yensign.circle.fill"
        case .moneyMoney:  return "dollarsign.circle.fill"
        case .custom:      return "doc.text.fill"
        }
    }

    /// 图标前景色
    var iconColor: String {
        switch self {
        case .alipay:     return "#1677FF"
        case .wechat:     return "#07C160"
        case .suishouji:  return "#FF6B35"
        case .moze:       return "#5856D6"
        case .qianji:     return "#FF9500"
        case .moneyMoney: return "#34C759"
        case .custom:     return "#8E8E93"
        }
    }

    /// 该来源的账单文件头部有元数据行，需要跳过到真正的表头
    var hasMetadataRows: Bool {
        switch self {
        case .alipay, .wechat: return true
        default: return false
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
        // 支付宝：交易时间|交易分类|交易对方|对方账号|商品说明|收/支|金额|收付款方式|交易状态|订单号|商家订单号|备注
        case .alipay:
            return [0: .date, 1: .category, 2: .payee, 3: .ignore, 4: .note,
                    5: .type, 6: .amount, 7: .ignore, 8: .ignore, 9: .ignore, 10: .ignore, 11: .ignore]
        // 微信：交易时间|交易类型|交易对方|商品|收/支|金额(元)|支付方式|当前状态|交易单号|商户单号|备注
        case .wechat:
            return [0: .date, 1: .category, 2: .payee, 3: .note,
                    4: .type, 5: .amount, 6: .ignore, 7: .ignore, 8: .ignore, 9: .ignore, 10: .ignore]
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

    // MARK: - 元数据行跳过（支付宝/微信账单头部有十几行说明文字）

    /// 扫描所有行，找到真正的数据表头所在行索引
    /// 判断依据：该行同时包含"交易时间"和"金额"这两个关键词
    static func findDataStartRow(in rows: [[String]]) -> Int {
        for (index, row) in rows.enumerated() {
            let joined = row.joined()
            if joined.contains("交易时间") && (joined.contains("金额") || joined.contains("收/支")) {
                return index
            }
        }
        return 0
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
        
        var cleanContent = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content

        // 关键修复：支付宝/微信导出的 CSV 是 Windows 换行（\r\n）。
        // Swift 的 String 按 Unicode 字形簇遍历字符，"\r\n" 这两个字节会被合并成
        // 一个 Character，导致下面 char == "\n" / char == "\r" 的判断永远为 false，
        // 换行符会被误当成普通文字拼进字段内容，整份文件被解析成一整行。
        // 所以在这里先统一把所有换行标准化成单个 "\n"，彻底避开这个坑。
        cleanContent = cleanContent.replacingOccurrences(of: "\r\n", with: "\n")
        cleanContent = cleanContent.replacingOccurrences(of: "\r", with: "\n")

        for char in cleanContent {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else if char == "\n" && !inQuotes {
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
    
    /// CSV 文本入口：先切分成二维数组，再交给下面的 rows 版本统一处理
    static func importTransactions(
        from csvContent: String,
        source: ImportSource,
        customMapping: [Int: CSVColumn]? = nil,
        categoryLookup: [String: Category]
    ) -> [ParsedTransaction] {
        importTransactions(rows: parseCSV(content: csvContent), source: source, customMapping: customMapping, categoryLookup: categoryLookup)
    }

    /// 通用入口：直接接收二维字符串数组（行 x 列）。
    /// CSV 和 xlsx 最终都会转换成这个统一结构，下面的列映射/日期解析等业务逻辑完全共用，不用重复实现。
    static func importTransactions(
        rows rawRows: [[String]],
        source: ImportSource,
        customMapping: [Int: CSVColumn]? = nil,
        categoryLookup: [String: Category]
    ) -> [ParsedTransaction] {
        var rows = rawRows
        guard rows.count > 1 else { return [] }

        // 支付宝/微信：跳过头部元数据行，定位到真正的列头行
        if source.hasMetadataRows {
            let startIndex = findDataStartRow(in: rows)
            rows = Array(rows.dropFirst(startIndex))
        }

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
            guard let tx = parseRow(row, mapping: mapping, categoryLookup: categoryLookup, source: source) else { continue }
            transactions.append(tx)
        }

        return transactions
    }
    
    private static func parseRow(_ row: [String], mapping: [Int: CSVColumn], categoryLookup: [String: Category], source: ImportSource = .custom) -> ParsedTransaction? {
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
            case .date:        dateStr       = value
            case .time:        timeStr       = value
            case .type:        typeStr       = value
            case .amount:      amountStr     = value
            case .category:    categoryStr   = value
            case .subcategory: subcategoryStr = value
            case .note:
                // 支付宝/微信可能有两个列映射到 note（商品说明 + 备注），取非空的那个
                if noteStr.isEmpty { noteStr = value }
            default: break
            }
        }

        // 支付宝"不计收支"（转账、充值、退款等）不属于收支记录，跳过
        if typeStr.contains("不计收支") { return nil }
        // 微信"/"收/支（理财等不明记录）同样跳过
        if typeStr == "/" { return nil }

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
            // 标准带零补位格式
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd",
            // 支付宝导出格式（月/日不补零，如 2026/7/15 15:28）
            "yyyy/M/d HH:mm:ss",
            "yyyy/M/d HH:mm",
            "yyyy/M/d",
            // 微信也会有类似的不补零格式
            "yyyy-M-d HH:mm:ss",
            "yyyy-M-d HH:mm",
            "yyyy-M-d",
            // 中文格式
            "yyyy年MM月dd日 HH:mm",
            "yyyy年M月d日 HH:mm",
            "yyyy年MM月dd日",
            "yyyy年M月d日",
            // 英文/国际格式
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

        // xlsx（Excel）场景：日期单元格存的是数字序列号（如 46215.940567129626），
        // 不是文本日期字符串，上面的格式都不会匹配，最后再按 Excel 序列号规则单独换算
        if let serial = Double(combined) {
            return excelSerialDateToDate(serial)
        }

        return nil
    }

    /// 把 Excel 的日期序列号换算成 Date
    /// Excel 以 1899-12-30 为第 0 天（这里沿用 Excel 自身的 1900 闰年 bug 惯例，
    /// 对 1900 年之后的日期没有影响，日常账单场景不需要额外处理）
    ///
    /// 注意：这里故意用固定 UTC 时区计算，不用 TimeZone.current，原因有两个：
    /// 1. 微信/支付宝账单里的时间都是北京时间（UTC+8），跟设备当前时区无关
    ///    （比如用户人在国外、手机时区不是中国时区，用 current 就会算错）；
    /// 2. 1899 年这么早的历史日期如果用真实的 Asia/Shanghai 时区换算，会踩到
    ///    历史偏移的坑——1949 年之前中国实际用的是 UTC+8:05:43（上海地方时），
    ///    不是整点 UTC+8，会导致换算结果多出 5 分 43 秒的误差。
    private static func excelSerialDateToDate(_ serial: Double) -> Date? {
        guard serial > 0 else { return nil }
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        var epochComponents = DateComponents()
        epochComponents.year = 1899
        epochComponents.month = 12
        epochComponents.day = 30
        guard let naiveEpoch = utcCalendar.date(from: epochComponents) else { return nil }
        let naiveResult = naiveEpoch.addingTimeInterval(serial * 86400)
        // naiveResult 目前是"把 Excel 裸时间当成 UTC"算出来的，
        // 减 8 小时校正成北京时间实际对应的 UTC 时刻，这样后续无论用什么时区显示都正确
        return naiveResult.addingTimeInterval(-8 * 3600)
    }
    
    /// CSV 文本入口
    static func previewData(from csvContent: String, source: ImportSource, customMapping: [Int: CSVColumn]? = nil) -> (headers: [String], rows: [[String]], mapping: [Int: CSVColumn]) {
        previewData(rows: parseCSV(content: csvContent), source: source, customMapping: customMapping)
    }

    /// 通用入口：直接接收二维字符串数组（CSV 和 xlsx 统一走这里）
    static func previewData(rows rawRows: [[String]], source: ImportSource, customMapping: [Int: CSVColumn]? = nil) -> (headers: [String], rows: [[String]], mapping: [Int: CSVColumn]) {
        var rows = rawRows
        guard !rows.isEmpty else { return ([], [], [:]) }

        // 支付宝/微信：跳过头部元数据，预览时同样需要对齐
        if source.hasMetadataRows {
            let startIndex = findDataStartRow(in: rows)
            rows = Array(rows.dropFirst(startIndex))
        }

        let mapping: [Int: CSVColumn]
        if let custom = customMapping {
            mapping = custom
        } else if source == .custom {
            mapping = detectColumns(from: rows[0])
        } else {
            mapping = columnMapping(for: source)
        }

        let headers = rows.first ?? []
        let previewRows = Array(rows.dropFirst().prefix(3))

        return (headers, previewRows, mapping)
    }
}
