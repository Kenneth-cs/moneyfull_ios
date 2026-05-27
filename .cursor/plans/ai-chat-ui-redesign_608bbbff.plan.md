---
name: ai-chat-ui-redesign
overview: Redesign the AIChatView to match the 'Soft Minimalism' aesthetic from the provided HTML/CSS reference, featuring a dot-grid background, translucent materials, asymmetric chat bubbles, and a new input area with quick action chips.
todos:
  - id: ui-background
    content: Create DotGridBackground view and apply to AIChatView
    status: pending
  - id: ui-header
    content: Redesign Header (TopAppBar) with glassmorphism and new layout
    status: pending
  - id: ui-bubbles
    content: Update ChatBubble styles (asymmetric corners, pastel colors)
    status: pending
  - id: ui-quick-actions
    content: Implement Quick Action Chips above input area
    status: pending
  - id: ui-input-bar
    content: Redesign Input Bar (pill shape, new send button colors)
    status: pending
isProject: false
---

# AI Chat UI Redesign Plan

Based on the provided `@AI交互页代码参考` (`code.html` and `DESIGN.md`), the goal is to transform the current `AIChatView` into a "Soft Minimalism" aesthetic. This involves moving away from heavy gradients to soft pastels, high-density whitespace, and exaggerated roundedness.

Here is the detailed plan to implement these changes:

## 1. Background & Overall Theme
- **Current**: Linear gradient from White to `#ECFDF5`.
- **Target**: A soft off-white (`#FAFBFA`) background with a subtle dot grid pattern.
- **Action**: 
  - Create a custom `DotGridBackground` view using SwiftUI `Canvas` or `Path` to draw faint dots (e.g., 2px dots spaced 24px apart with 3% black opacity).
  - Apply this background to the main `AIChatView`.

## 2. Header (TopAppBar) Redesign
- **Current**: Solid green gradient background, title "AI 助手", back button on left, avatar on left, trash on right.
- **Target**: Translucent glassmorphism effect, centered title, avatar on the right.
- **Action**:
  - Remove the green `LinearGradient` background and replace it with `.background(.ultraThinMaterial)` or `Color.white.opacity(0.7)` with `.backgroundBlur()`.
  - Change the title to `✨ 小满-您的财务管家 ✨` with text color `#226552` and bold rounded font.
  - Move the `CapybaraAvatar` to the right side of the header.
  - Style the back button as a circular button with a white background, subtle shadow, and `#226552` icon.

## 3. Chat Bubbles (`ChatBubble` struct)
- **Current**: User is green gradient, AI is white with green border. Both use symmetric 16px corner radius.
- **Target**: Asymmetric bubbles (24px radius with one 8px sharp corner), soft pastel colors.
- **Action**:
  - **User Bubble**: 
    - Background: White (`Color.white.opacity(0.9)`).
    - Text Color: Dark Charcoal (`#191C1C`).
    - Shape: `UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 8)`.
    - Shadow: Very subtle ambient shadow.
  - **AI Bubble**:
    - Background: Light Mint (`#F0FBF6`).
    - Text Color: Dark Green (`#1A4D3E`).
    - Border: 1px solid `#9EE0C8` at 30% opacity.
    - Shape: `UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 24)`.

## 4. Input Area & Quick Actions
- **Current**: Simple text field with gray background, photo/mic buttons on left, send button on right.
- **Target**: Floating quick action chips above a pill-shaped input bar.
- **Action**:
  - **Quick Action Chips**: Add a horizontal `ScrollView` above the input field containing pill-shaped buttons (e.g., "💰 本月预算", "💡 省钱建议", "📊 导出账单").
  - **Input Bar**: Wrap the input elements in a `Capsule()` with a white translucent background, subtle border (`#E1E3E2`), and shadow.
  - **Send Button**: Change to a circular button with Mint background (`#9EE0C8`) and dark green icon (`#002118`).
  - **Typography**: Update the placeholder and input text to use a rounded, friendly font style.

## 5. Typography & Polish
- **Action**: Apply `.fontDesign(.rounded)` to system fonts throughout the chat view to mimic the friendly "Plus Jakarta Sans" vibe from the design spec.

---
*Note: This plan focuses on the visual overhaul of `AIChatView.swift`. The underlying logic for sending messages and handling intents will remain untouched.*