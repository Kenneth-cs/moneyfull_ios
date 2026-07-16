import Foundation
import Compression

/// 最小化的 xlsx（Office Open XML）读取器
///
/// xlsx 本质上是一个 ZIP 压缩包，内部包含若干 XML 文件（工作表数据、共享字符串表等）。
/// 微信支付账单导出的就是这种格式，直接当作 UTF-8 文本读取会得到乱码（ZIP 是二进制格式）。
///
/// 这里不引入第三方库，用系统自带的 Compression 框架实现最小可用的 ZIP 解压 + XML 解析，
/// 只读取第一个工作表的单元格数据，输出格式与 CSV 解析结果一致（`[[String]]`），
/// 这样可以直接复用 CSVImportService 里已有的列映射、日期解析等逻辑，不用重复实现业务规则。
enum XLSXReader {

    /// 解析 xlsx 文件的第一个工作表，返回二维字符串数组（行 x 列），失败返回 nil
    static func parseFirstSheetRows(data: Data) -> [[String]]? {
        let bytes = [UInt8](data)
        guard let entries = extractEntries(
            from: bytes,
            wanted: ["xl/worksheets/sheet1.xml", "xl/sharedStrings.xml"]
        ), let sheetXML = entries["xl/worksheets/sheet1.xml"] else {
            return nil
        }

        let sharedStrings = entries["xl/sharedStrings.xml"].map(parseSharedStrings) ?? []
        return parseSheetRows(sheetXML, sharedStrings: sharedStrings)
    }

    // MARK: - 最小 ZIP 读取（只支持 Stored / Deflate 两种常见压缩方式，够用于 Excel 生成的 xlsx）

    private static func extractEntries(from bytes: [UInt8], wanted: Set<String>) -> [String: Data]? {
        let count = bytes.count
        guard count > 22 else { return nil }

        func u16(_ offset: Int) -> Int {
            Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
        }
        func u32(_ offset: Int) -> Int {
            Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
                | (Int(bytes[offset + 2]) << 16) | (Int(bytes[offset + 3]) << 24)
        }

        // 从文件末尾往前找 "End Of Central Directory" 签名 50 4B 05 06
        // ZIP 注释区最长 65535 字节，从后往前扫这一小段范围即可，没必要整份文件扫描
        let searchFloor = max(0, count - 22 - 65536)
        var eocdOffset = -1
        var i = count - 22
        while i >= searchFloor {
            if bytes[i] == 0x50, bytes[i+1] == 0x4b, bytes[i+2] == 0x05, bytes[i+3] == 0x06 {
                eocdOffset = i
                break
            }
            i -= 1
        }
        guard eocdOffset >= 0 else { return nil }

        let totalEntries = u16(eocdOffset + 10)
        let centralDirOffset = u32(eocdOffset + 16)

        var results: [String: Data] = [:]
        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= count else { break }
            // Central Directory File Header 签名 50 4B 01 02
            guard bytes[offset] == 0x50, bytes[offset+1] == 0x4b, bytes[offset+2] == 0x01, bytes[offset+3] == 0x02 else { break }

            let compressionMethod = u16(offset + 10)
            let compressedSize = u32(offset + 20)
            let uncompressedSize = u32(offset + 24)
            let filenameLen = u16(offset + 28)
            let extraLen = u16(offset + 30)
            let commentLen = u16(offset + 32)
            let localHeaderOffset = u32(offset + 42)

            let filenameStart = offset + 46
            guard filenameStart + filenameLen <= count else { break }
            let filename = String(decoding: bytes[filenameStart..<(filenameStart + filenameLen)], as: UTF8.self)

            if wanted.contains(filename) {
                if let extracted = extractLocalFile(
                    bytes: bytes,
                    localHeaderOffset: localHeaderOffset,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize
                ) {
                    results[filename] = extracted
                }
            }

            offset = filenameStart + filenameLen + extraLen + commentLen
            if results.count == wanted.count { break }
        }

        return results.isEmpty ? nil : results
    }

    private static func extractLocalFile(
        bytes: [UInt8],
        localHeaderOffset: Int,
        compressionMethod: Int,
        compressedSize: Int,
        uncompressedSize: Int
    ) -> Data? {
        func u16(_ offset: Int) -> Int {
            Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
        }
        let offset = localHeaderOffset
        guard offset + 30 <= bytes.count else { return nil }
        // Local File Header 签名 50 4B 03 04
        guard bytes[offset] == 0x50, bytes[offset+1] == 0x4b, bytes[offset+2] == 0x03, bytes[offset+3] == 0x04 else { return nil }

        let filenameLen = u16(offset + 26)
        let extraLen = u16(offset + 28)
        let dataStart = offset + 30 + filenameLen + extraLen
        guard dataStart + compressedSize <= bytes.count else { return nil }

        let compressedBytes = Array(bytes[dataStart..<(dataStart + compressedSize)])

        switch compressionMethod {
        case 0: // Stored，未压缩
            return Data(compressedBytes)
        case 8: // Deflate，用系统 Compression 框架做 raw inflate
            return inflate(compressedBytes, expectedSize: uncompressedSize)
        default:
            return nil
        }
    }

    private static func inflate(_ compressed: [UInt8], expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        var destBuffer = [UInt8](repeating: 0, count: expectedSize)
        let decodedSize = destBuffer.withUnsafeMutableBufferPointer { dstPtr -> Int in
            compressed.withUnsafeBufferPointer { srcPtr -> Int in
                guard let dstBase = dstPtr.baseAddress, let srcBase = srcPtr.baseAddress else { return 0 }
                // ZIP 内的 deflate 数据是不带 zlib/gzip 包装的 raw deflate 流，
                // Apple Compression 框架的 COMPRESSION_ZLIB 算法恰好对应 raw deflate 解码
                return compression_decode_buffer(dstBase, expectedSize, srcBase, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard decodedSize > 0 else { return nil }
        return Data(destBuffer[0..<decodedSize])
    }

    // MARK: - sharedStrings.xml 解析（共享字符串表，单元格文本大多以索引形式引用这里的值）

    private static func parseSharedStrings(_ data: Data) -> [String] {
        let delegate = SharedStringsParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private final class SharedStringsParserDelegate: NSObject, XMLParserDelegate {
        var strings: [String] = []
        private var currentText = ""
        private var isInText = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "si" {
                currentText = ""
            } else if elementName == "t" {
                isInText = true
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if isInText { currentText += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "t" {
                isInText = false
            } else if elementName == "si" {
                strings.append(currentText)
            }
        }
    }

    // MARK: - sheet1.xml 解析（真正的单元格数据）

    private static func parseSheetRows(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetParserDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    private final class SheetParserDelegate: NSObject, XMLParserDelegate {
        private let sharedStrings: [String]
        var rows: [[String]] = []

        private var currentRowCells: [Int: String] = [:]   // 列索引 -> 值（稀疏存储，跳过空单元格）
        private var maxColIndexInRow = -1
        private var currentCellType: String?
        private var currentCellColIndex = -1
        private var currentValue = ""
        private var isInValue = false

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "row":
                currentRowCells = [:]
                maxColIndexInRow = -1
            case "c":
                currentCellType = attributeDict["t"]
                currentCellColIndex = Self.columnIndex(from: attributeDict["r"] ?? "")
                currentValue = ""
            case "v", "t":
                isInValue = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if isInValue { currentValue += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "v", "t":
                isInValue = false
            case "c":
                let resolved: String
                if currentCellType == "s", let idx = Int(currentValue), idx >= 0, idx < sharedStrings.count {
                    resolved = sharedStrings[idx]
                } else {
                    resolved = currentValue
                }
                if currentCellColIndex >= 0 {
                    currentRowCells[currentCellColIndex] = resolved
                    maxColIndexInRow = max(maxColIndexInRow, currentCellColIndex)
                }
            case "row":
                if maxColIndexInRow < 0 {
                    rows.append([])
                } else {
                    var rowArray = [String](repeating: "", count: maxColIndexInRow + 1)
                    for (idx, val) in currentRowCells {
                        rowArray[idx] = val
                    }
                    rows.append(rowArray)
                }
            default:
                break
            }
        }

        /// 把 "A1" "AB12" 这样的单元格引用转换成从 0 开始的列索引
        static func columnIndex(from cellRef: String) -> Int {
            var col = 0
            for ch in cellRef {
                guard ch.isASCII, ch.isLetter else { break }
                let value = Int(ch.asciiValue!) - Int(Character("A").asciiValue!) + 1
                col = col * 26 + value
            }
            return col - 1
        }
    }
}
