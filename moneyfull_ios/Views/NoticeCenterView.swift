import SwiftUI
import SwiftData

/// 消息中心：首页铃铛点开的列表页
/// 目前只有"给陪伴的你"这一条老用户福利通知，后续新公告直接往 AppNoticeData.all 里加即可自动出现在这里
struct NoticeCenterView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNotice: AppNotice?

    var body: some View {
        NavigationView {
            ZStack {
                Color.App.backgroundGray.ignoresSafeArea()

                if store.appNotices.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(store.appNotices, id: \.noticeID) { notice in
                                NoticeRow(notice: notice)
                                    .onTapGesture {
                                        store.markNoticeAsRead(notice)
                                        selectedNotice = notice
                                    }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("消息中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                }
            }
        }
        .sheet(item: $selectedNotice) { notice in
            NoticeDetailSheet(notice: notice)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🔔")
                .font(.system(size: 40))
            Text("暂时没有新消息")
                .font(.system(size: 15))
                .foregroundColor(Color.App.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Notice Row

private struct NoticeRow: View {
    let notice: AppNotice

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: notice.receivedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.App.lightGreen.opacity(0.5))
                    .frame(width: 44, height: 44)
                Text("💌")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)

                if !notice.isRead {
                    Circle()
                        .fill(Color.App.redExpense)
                        .frame(width: 9, height: 9)
                        .offset(x: 2, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.system(size: 15, weight: notice.isRead ? .medium : .bold))
                    .foregroundColor(Color.App.textBlack)
                Text(dateText)
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.App.textSecondary.opacity(0.6))
        }
        .padding(14)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Notice Detail Sheet（按 noticeID 分发到对应的详情样式）

private struct NoticeDetailSheet: View {
    let notice: AppNotice
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if notice.noticeID == AppNoticeData.legacyGiftLetter.id {
            LegacyGiftLetterView(isLegacyUser: storeManager.isLegacyGiftActive, onDismiss: { dismiss() })
        } else {
            GenericNoticeDetailView(notice: notice, onDismiss: { dismiss() })
        }
    }
}

/// 未来新增的通用公告（没有专属插画时）走这个简单样式
private struct GenericNoticeDetailView: View {
    let notice: AppNotice
    let onDismiss: () -> Void

    private var content: AppNoticeContent? {
        AppNoticeData.content(for: notice.noticeID)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if let content {
                        Text(content.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Color.App.textSecondary)
                        NoticeParagraphRenderer(paragraphs: content.paragraphs)
                    } else {
                        Text("内容暂不可用")
                            .foregroundColor(Color.App.textSecondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle(notice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭", action: onDismiss)
                }
            }
        }
    }
}

#Preview {
    NoticeCenterView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self, ProjectReviewCache.self, LegacyGiftGrant.self, AppNotice.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
}
