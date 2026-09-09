The user is asking about what other system-level services Apple provides that are free to use, similar to the Speech framework. This is a general knowledge question about iOS/Apple frameworks, not specifically about the codebase. I'll provide a comprehensive overview of Apple's free system-level services/frameworks that developers can use without additional cost.
Apple 提供了大量免费的系统级服务/框架，开发者可以直接调用，**不需要额外付费**。按类别整理如下：

---

## 🎤 语音与语言类

| 框架 | 功能 | 备注 |
|------|------|------|
| **Speech** (`SFSpeechRecognizer`) | 语音转文字，支持 50+ 种语言 | 当前钱小满在用 |
| **NaturalLanguage** | 文本语言识别、分词、词性标注、情感分析、命名实体识别 | 完全离线可用 |
| **Translation** (`Translation`) | 实时语音/文本翻译 | iOS 17.4+，支持离线包 |
| **AVSpeechSynthesizer** | 文字转语音（TTS） | 系统内置多种声音 |
| **LinguisticTagger** | 文本语言学分析（分词、词性、词形还原） | 已被 NaturalLanguage 部分替代 |

---

## 👁️ 视觉与图像类

| 框架 | 功能 | 备注 |
|------|------|------|
| **Vision** (`VNCoreMLRequest`) | 人脸检测、文字识别（OCR）、图像分类、物体追踪、人体姿态 | 非常强大，钱小满的 [VisionService](file:///Users/cs/Desktop/CS/AI/moneyfull_ios/moneyfull_ios/Services/VisionService.swift) 应该有用到 |
| **Core ML** | 在设备端运行机器学习模型 | 可加载自定义或 Apple 提供的模型 |
| **VisionKit** | 文档扫描、实况文本（Live Text）、视觉查找 | iOS 16+ |
| **AVFoundation** | 视频/音频录制、编辑、播放 | 系统级，完全免费 |

---

## 📍 位置与地图类

| 框架 | 功能 | 备注 |
|------|------|------|
| **CoreLocation** | GPS 定位、地理围栏、逆地理编码 | 免费，但需要用户授权 |
| **MapKit** | 地图展示、路线规划、地理编码 | 完全免费（替代高德/百度地图） |
| **CoreMotion** | 加速度计、陀螺仪、计步器、气压计 | 设备传感器数据 |

---

## 🔐 安全与身份验证类

| 框架 | 功能 | 备注 |
|------|------|------|
| **LocalAuthentication** | Face ID / Touch ID 生物识别 | 系统级，免费 |
| **Security** | Keychain 存储、证书验证 | 系统级 |
| **CryptoKit** | 加密、哈希、签名 | 系统级 |
| **App Attest** | 防止 App 被篡改、防机器人 | iOS 14+ |

---

## 📱 UI 与交互类

| 框架 | 功能 | 备注 |
|------|------|------|
| **SwiftUI** | 声明式 UI 框架 | 钱小满主要 UI 框架 |
| **WidgetKit** | 桌面小组件 | 免费 |
| **UserNotifications** | 本地/远程推送通知 | 系统级 |
| **Shortcuts / SiriKit** | Siri 语音指令集成 | 系统级 |
| **TipKit** | 功能引导提示气泡 | iOS 17+ |

---

## 💾 数据与存储类

| 框架 | 功能 | 备注 |
|------|------|------|
| **SwiftData** | 数据持久化（替代 Core Data） | 钱小满在用 |
| **CloudKit** | iCloud 云同步 | 免费额度很大（10GB 数据库 + 100MB/天请求） |
| **CoreSpotlight** | 系统搜索集成（Spotlight） | 让 App 内容出现在系统搜索中 |
| **App Groups** | App 间数据共享、Widget 数据互通 | 系统级 |

---

## 🔗 网络与通信类

| 框架 | 功能 | 备注 |
|------|------|------|
| **URLSession** | HTTP 网络请求 | 钱小满调用千问 API 用的就是这个 |
| **Network** (`NWConnection`) | 底层网络（TCP/UDP/QUIC） | 系统级 |
| **MultipeerConnectivity** | 近场设备发现和通信（Wi-Fi/蓝牙） | 免费，无需网络 |
| **NearbyInteraction** | UWB 精确测距 | 需要 U1 芯片 |

---

## 📊 分析与性能类

| 框架 | 功能 | 备注 |
|------|------|------|
| **MetricKit** | App 性能指标收集（崩溃、电量、内存） | 系统级 |
| **os_signpost** | 性能打点和分析 | 系统级 |
| **XCTest** | 单元测试/UI 测试 | 开发阶段免费 |

---

## 🏥 健康与运动类

| 框架 | 功能 | 备注 |
|------|------|------|
| **HealthKit** | 读写健康数据（步数、心率等） | 免费 |
| **WorkoutKit** | 运动训练计划 | iOS 17+ |

---

## 💡 对钱小满有潜力的免费服务

结合钱小满是一款记账+AI助手的 App，以下免费框架可能对你有额外价值：

1. **NaturalLanguage** — 可以对用户的记账备注做语义分析（如"午饭"→餐饮分类），减少 LLM 调用，节省千问 API 费用
2. **Vision (OCR)** — 拍照识别小票/发票金额，已在使用
3. **CloudKit** — 免费的 iCloud 同步，可以替代自建云后端做数据同步
4. **CoreSpotlight** — 让记账记录可以在系统搜索中被找到
5. **WidgetKit** — 显示今日支出/预算剩余等桌面小组件
6. **Translation** — 如果未来要做多语言支持

---

总结：Apple 的系统级服务覆盖了语音、视觉、NLP、定位、安全、存储、网络等方方面面，**全部免费且不需要 API Key**。开发者唯一的"成本"是 iOS 版本兼容性——很多新框架需要 iOS 16/17+。