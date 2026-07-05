import SwiftUI

// MARK: - 有内容时的遮罩型锁定（内容真实可见但模糊）

struct PlusLockedSection<Content: View>: View {
    let isLocked: Bool
    let title: String
    var onUnlock: () -> Void = {}
    let content: Content

    init(
        isLocked: Bool,
        title: String,
        onUnlock: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.isLocked = isLocked
        self.title    = title
        self.onUnlock = onUnlock
        self.content  = content()
    }

    var body: some View {
        if isLocked {
            ZStack {
                content
                    .blur(radius: 8)
                    .allowsHitTesting(false)

                VStack(spacing: 10) {
                    plusBadge
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                        .multilineTextAlignment(.center)
                    Button(action: onUnlock) {
                        Text("升级解锁")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.App.darkGreen)
                            .clipShape(Capsule())
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .clipped()
        } else {
            content
        }
    }
}

// MARK: - 无内容时的入口锁定卡（功能说明型）

struct PlusLockedEntryCard: View {
    let icon: String
    let title: String
    let description: String
    let features: [String]
    var onUnlock: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                    Text(title)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
                plusBadge
            }

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feat in
                    HStack(spacing: 8) {
                        Circle().fill(Color.App.primaryGreen).frame(width: 5, height: 5)
                        Text(feat)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.App.textBlack.opacity(0.75))
                    }
                }
            }

            Button(action: onUnlock) {
                Text("解锁\(title)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.App.darkGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
}

// MARK: - Plus 角标（共用）

private var plusBadge: some View {
    HStack(spacing: 4) {
        Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
        Text("Plus").font(.system(size: 12, weight: .heavy))
    }
    .foregroundColor(Color.App.darkGreen)
    .padding(.horizontal, 10).padding(.vertical, 4)
    .background(Color.App.primaryGreen.opacity(0.25))
    .clipShape(Capsule())
}
