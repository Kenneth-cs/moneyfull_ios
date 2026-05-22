# 钱小满「快捷记账」Shortcut 分发落地文档

> 最后更新：2026-05-21
> 状态：✅ 已实现

---

## 一、整体原理

采用 **App Intent + URL Scheme 桥梁方案**，用户只需 3 步即可完成记账：

```
截屏 → 从截屏中提取文本 → 钱小满（内容：图像中的文本）
        ↓
Intent 接收文本 → URL 编码 → openURL 唤起 App
        ↓
ContentView.onOpenURL → 解析文本 → 通知 MainTabView → AIChatView 自动处理
        ↓
AI 解析账单信息，弹出「确认卡片」，用户点确认即完成入账
```

### 方案优势

1. **用户体验极简**：快捷指令只需 3 步，不需要用户懂 URL
2. **彻底解决 CloudKit 崩溃**：Intent 内部不碰数据库，只做 URL 跳转
3. **无粘贴权限弹窗**：不使用剪贴板，体验更流畅
4. **无 URL 长度限制**：通过 URL 编码传递，不受 Base64 截断影响

---

## 二、技术实现

### 1. RecordTransactionIntent.swift（桥梁方案）

```swift
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
        // URL 编码文本
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "moneyfull://ai?text=\(encodedText)") else {
            return .result()
        }
        
        // 唤起 App
        openURL(url)
        
        return .result()
    }
}
```

### 2. ContentView.swift（Deep Link 处理）

```swift
.onOpenURL { url in
    handleDeepLink(url)
}

private func handleDeepLink(_ url: URL) {
    guard url.scheme == "moneyfull",
          url.host == "ai",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return }
    
    // 处理 text 参数
    if let item = components.queryItems?.first(where: { $0.name == "text" }),
       let rawText = item.value, !rawText.isEmpty {
        let decoded = rawText.removingPercentEncoding ?? rawText
        NotificationCenter.default.post(name: .deepLinkReceived, object: decoded)
    }
}
```

### 3. AIChatView.swift（快捷指令来源不显示用户气泡）

```swift
var initialText: String?
var isFromShortcut: Bool = false

.onAppear {
    if let text = initialText, !text.isEmpty {
        if isFromShortcut {
            // 快捷指令来源：不显示用户气泡，直接显示 AI 处理
            processOCRText(text)
        } else {
            // 语音/手动输入：正常显示用户气泡
            messageText = text
            sendMessage()
        }
    }
}
```

---

## 三、快捷指令配置

### 用户操作步骤

1. 打开「快捷指令」App
2. 点击右上角「+」创建新快捷指令
3. 添加操作：
   - **截屏**
   - **从截屏中提取文本**
   - **钱小满**（内容：图像中的文本）
4. 保存并命名为「钱小满自动记账」
5. 在「设置→辅助功能→触控→轻点背面→轻点两下」中绑定

### 快捷指令流程

```
截屏
  ↓
从截屏中提取文本
  ↓
钱小满
  内容：图像中的文本
```

---

## 四、使用场景

### 场景一：微信/支付宝支付后

1. 用户完成支付，看到支付成功页面
2. 双击手机背面
3. 快捷指令自动截屏、提取文本、打开钱小满
4. AI 自动识别金额、商户、分类
5. 弹出确认卡片，用户点击确认即完成记账

### 场景二：查看账单详情时

1. 用户打开微信/支付宝的账单详情页面
2. 双击手机背面
3. 自动完成记账

---

## 五、注意事项

1. **OCR 准确率**：iOS 原生 OCR 对标准支付页面准确率很高，但对复杂排版可能有误差
2. **隐私保护**：所有处理在端侧完成，OCR 文本只在本地处理
3. **iCloud 同步**：记账数据通过 CloudKit 自动同步到所有设备
4. **快捷指令更新**：如果更新快捷指令内容，需要用户重新安装

---

## 六、后续优化方向

1. **批量导入**：支持月底批量截图账单列表，AI 一次性解析多条账单
2. **Siri 语音**：支持「嘿 Siri，用钱小满记一笔，打车 50 块」
3. **锁屏小组件**：一键录音记账
4. **短信自动化**：收到银行短信时自动触发记账

---

快捷指令 OCR 记账功能已完成！🎉
