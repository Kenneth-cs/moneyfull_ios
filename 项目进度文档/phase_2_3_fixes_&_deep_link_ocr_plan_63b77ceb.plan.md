---
name: Phase 2/3 Fixes & Deep Link OCR Plan
overview: Fix voice recording functionality in TabBar and ChatView, implement Deep Link handling for Shortcut OCR, and create the Back Tap tutorial view.
todos:
  - id: implement-voice-recording
    content: Implement voice recording logic in MainTabView and AIChatView
    status: pending
  - id: add-url-scheme-handling
    content: Add URL Scheme handling for moneyfull://ai?text=...
    status: pending
  - id: create-backtap-tutorial
    content: Create BackTapTutorialView and add entry in ProfileView
    status: pending
isProject: false
---

# 语音功能与快捷指令 OCR 实施计划

## 1. 语音功能补全 (Voice Recording)
- **修改文件**: `moneyfull_ios/Views/MainTabView.swift`
  - 完善底部 AI 按钮的长按逻辑：
    - `onLongPressStart`: 请求麦克风权限，若授权则调用 `SpeechService.shared.startRecording()`。
    - `onLongPressEnd`: 调用 `SpeechService.shared.stopRecording()`，获取 `transcribedText`。
    - 将识别到的文本通过 Binding 或 EnvironmentObject 传递给 `AIChatView`，使其在打开时自动发送该文本并请求 LLM。
- **修改文件**: `moneyfull_ios/Views/AIChatView.swift`
  - 增加接收初始文本的逻辑：如果传入了初始文本（来自首页长按语音，或来自 URL Scheme），在 `onAppear` 时自动调用 `sendMessage()`。
  - 确保内部的语音输入按钮（按住说话）能正确调用 `SpeechService` 并发送消息。

## 2. URL Scheme 与 Deep Link 处理 (Shortcut OCR)
- **修改文件**: `moneyfull_ios/moneyfull_iosApp.swift` 或 `moneyfull_ios/Views/ContentView.swift`
  - 添加 `.onOpenURL` 监听器，拦截 `moneyfull://ai?text=...` 格式的 Deep Link。
  - **原理解释（回答您的疑问）**：iOS 自带的快捷指令 OCR（提取图像中的文本）准确率极高，特别是针对微信/支付宝这种标准字体的支付页面。提取出纯文本后，通过 URL 传给 App，App 会**再次把这段纯文本丢给 LLM** 进行意图识别和结构化提取，最终在 AI 对话页弹出确认卡片。这比把整张图片传给云端大模型更准、更快、更省钱。
  - 接收到 URL 后，解析出 `text` 参数，设置全局状态，触发弹出 `AIChatView` 并自动处理该文本。

## 3. 快捷指令教程页 (Back Tap Tutorial)
- **新建文件**: `moneyfull_ios/Views/BackTapTutorialView.swift`
  - 编写图文教程，指导用户在“快捷指令”App中创建自动化：
    1. 操作1：获取屏幕截图 (Take Screenshot)
    2. 操作2：从图像中提取文本 (Extract Text from Image)
    3. 操作3：URL 编码 (URL Encode) 提取的文本
    4. 操作4：打开 URL `moneyfull://ai?text=[URL编码后的文本]`
  - 指导用户在 iOS 设置 -> 辅助功能 -> 触控 -> 轻点背面 中绑定此快捷指令。
- **修改文件**: `moneyfull_ios/Views/ProfileView.swift`
  - 在“账户管理”列表中增加“快捷记账 (轻点背面)”入口，点击跳转到教程页。