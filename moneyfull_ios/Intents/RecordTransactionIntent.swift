import AppIntents
import SwiftUI

struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "钱小满"
    static var description = IntentDescription("从截图中识别账单信息并记账")
    
    @Parameter(title: "内容")
    var text: String
    
    @Environment(\.openURL) var openURL
    
    static var parameterSummary: some ParameterSummary {
        Summary("内容：\(\.$text)")
    }
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "moneyfull://ai?text=\(encodedText)") else {
            return .result()
        }
        
        openURL(url)
        
        return .result()
    }
}
