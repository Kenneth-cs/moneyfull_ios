---
name: Phase 2 VLM and System Integration Plan
overview: Implement Phase 2 of the Moneyfull v2.0 AI Native upgrade, including Vision OCR for image-based transactions, App Intents for Siri integration, and a Back Tap tutorial.
todos:
  - id: create-vision-service
    content: Create VisionService for OCR text extraction
    status: pending
  - id: update-llm-service-ocr
    content: Update LLMService with parseOCRText method
    status: pending
  - id: update-chat-view-image
    content: Add PhotosPicker and image handling to AIChatView
    status: pending
  - id: create-app-intent
    content: Create RecordTransactionIntent for Siri integration
    status: pending
  - id: create-tutorial-view
    content: Create BackTapTutorialView and add entry in ProfileView
    status: pending
  - id: implement-deep-link
    content: Implement Deep Link handling for Widget integration
    status: pending
isProject: false
---

# Phase 2: 视觉解析与系统级整合 实施计划

## 1. 视觉记账 (VLM / OCR)
- **新建文件**: `moneyfull_ios/Services/VisionService.swift`
  - 封装 iOS 原生 `Vision` 框架 (`VNRecognizeTextRequest`)，实现从 `UIImage` 提取纯文本的功能。
- **修改文件**: `moneyfull_ios/Services/LLMService.swift`
  - 新增 `parseOCRText(from text: String, context: String)` 方法，专门针对 OCR 提取的凌乱文本（包含时间、商户、金额等）进行解析，复用一二级分类的识别逻辑。
- **修改文件**: `moneyfull_ios/Views/AIChatView.swift`
  - 引入 `PhotosUI` (`PhotosPicker`)。
  - 在底部的输入框区域（左侧或右侧）新增一个“相册/拍照”图标按钮。
  - 用户选择图片后，在聊天界面展示一张图片气泡，并显示“正在识别账单...”。
  - 调用 `VisionService` 提取文本，然后调用 `LLMService.parseOCRText`，最后渲染 `TransactionConfirmCard`。

## 2. iOS 系统整合 (App Intents & Shortcuts)
- **新建文件夹及文件**: `moneyfull_ios/Intents/RecordTransactionIntent.swift`
  - 引入 `AppIntents` 框架。
  - 定义 `RecordTransactionIntent`，设置标题为“用钱小满记一笔”。
  - 接收一个 `String` 类型的参数（用户的自然语言输入）。
  - 在 `perform()` 方法中，后台调用 `LLMService` 解析文本并直接写入 `SwiftData` 的 `ModelContext`。
- **新建文件**: `moneyfull_ios/Views/BackTapTutorialView.swift`
  - 编写一个图文并茂的教程页面，指导用户如何：
    1. 在“快捷指令”App 中创建一个截屏并传给钱小满的指令。
    2. 在 iOS 设置 -> 辅助功能 -> 触控 -> 轻点背面 中绑定该快捷指令。
- **修改文件**: `moneyfull_ios/Views/ProfileView.swift`
  - 在“我的”页面列表中，新增一行“快捷记账设置 (轻点背面)”，点击跳转至 `BackTapTutorialView`。

## 3. 锁屏小组件 (Lock Screen Widget)
- **说明**: 创建 Widget 需要在 Xcode 中新增 Target，这部分将以提供代码和操作指南的形式完成。
- **计划**: 
  - 提供 `Widget.swift` 的代码实现，包含一个简单的圆形按钮，点击后通过 Deep Link (如 `moneyfull://record`) 唤起 App 并直接进入录音状态。
  - 在 `moneyfull_iosApp.swift` 或 `ContentView.swift` 中处理 `onOpenURL`，接收到 Deep Link 时自动弹出 `AIChatView` 并触发录音。