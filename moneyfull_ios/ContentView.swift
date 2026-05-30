import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: AppStore?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var deepLinkText: String?
    @State private var showRatingPrompt = false

    var body: some View {
        Group {
            if let store = store {
                MainTabView()
                    .environmentObject(store)
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                    }
            } else {
                Color.App.backgroundGray.ignoresSafeArea()
            }
        }
        .onAppear {
            if store == nil {
                store = AppStore(modelContext: modelContext)
            }
            
            if let store = store, AppRatingManager.shared.shouldShowRating(transactionCount: store.recentTransactions.count) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showRatingPrompt = true
                }
            }
        }
        .overlay {
            if showRatingPrompt, let store = store {
                AppRatingPromptView(
                    isPresented: $showRatingPrompt,
                    onRate: {
                        AppRatingManager.shared.openAppStore()
                    },
                    onFeedback: {
                        NotificationCenter.default.post(name: .showFeedback, object: nil)
                    }
                )
            }
        }
        // MARK: - URL Scheme 处理（备选方案，主要方案是 App Intent）
        // 保留此代码作为备选方案，如果 App Intent 效果不好可以回退到此方案
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("📱 Deep Link received: \(url)")
        #endif
        
        guard url.scheme == "moneyfull",
              url.host == "ai",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            #if DEBUG
            print("❌ Deep Link: scheme/host/components 解析失败")
            #endif
            return
        }
        
        let queryItems = components.queryItems ?? []
        #if DEBUG
        print("📱 Deep Link queryItems: \(queryItems.map { "\($0.name)=\($0.value?.prefix(50) ?? "nil")" })")
        #endif
        
        // 优先处理 clipboard 参数（从剪贴板读取 OCR 文本）
        if queryItems.first(where: { $0.name == "clipboard" }) != nil {
            if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
                #if DEBUG
                print("✅ Deep Link: 从剪贴板读取文本，长度: \(clipboardText.count)")
                #endif
                deepLinkText = clipboardText
                NotificationCenter.default.post(name: .deepLinkReceived, object: clipboardText)
                return
            }
        }
        
        // 处理 image 参数（Base64 编码的 OCR 文本）
        if let item = queryItems.first(where: { $0.name == "image" }),
           let base64Value = item.value, !base64Value.isEmpty {
            #if DEBUG
            print("📱 Deep Link: 找到 image 参数，长度: \(base64Value.count)")
            #endif
            
            // 修复 Base64 中的空格（URL 会把 + 变成空格）
            let fixedBase64 = base64Value.replacingOccurrences(of: " ", with: "+")
            
            // 尝试 Base64 解码
            if let data = Data(base64Encoded: fixedBase64),
               let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
                #if DEBUG
                print("✅ Deep Link: Base64 解码成功，文本: \(decoded.prefix(100))")
                #endif
                deepLinkText = decoded
                NotificationCenter.default.post(name: .deepLinkReceived, object: decoded)
                return
            }
            
            // Base64 解码失败，尝试直接 URL 解码（兼容非 Base64 格式）
            let urlDecoded = base64Value.removingPercentEncoding ?? base64Value
            if !urlDecoded.isEmpty {
                #if DEBUG
                print("✅ Deep Link: 使用 URL 解码，文本: \(urlDecoded.prefix(100))")
                #endif
                deepLinkText = urlDecoded
                NotificationCenter.default.post(name: .deepLinkReceived, object: urlDecoded)
                return
            }
        }
        
        // 兼容旧的 text / ocr_text 参数
        if let item = queryItems.first(where: { $0.name == "text" || $0.name == "ocr_text" }),
           let rawText = item.value, !rawText.isEmpty {
            let decoded = rawText.removingPercentEncoding ?? rawText
            #if DEBUG
            print("✅ Deep Link: text 参数解码成功，文本: \(decoded.prefix(100))")
            #endif
            deepLinkText = decoded
            NotificationCenter.default.post(name: .deepLinkReceived, object: decoded)
        } else {
            #if DEBUG
            print("❌ Deep Link: 未找到有效的 text/image 参数")
            #endif
        }
    }
}

extension Notification.Name {
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
    static let showFeedback = Notification.Name("showFeedback")
    static let newShortcutText = Notification.Name("newShortcutText")
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self], inMemory: true)
}

