import SwiftUI

struct FinancialAcademyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.App.backgroundGray.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.App.darkGreen)
                            .frame(width: 44, height: 44)
                            .background(Color.App.cardBackground.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                    }
                    Spacer()
                    Text("✨ 财商学堂 ✨")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.App.darkGreen)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.App.cardBackground.opacity(0.7).background(.ultraThinMaterial).ignoresSafeArea(edges: .top))
                .overlay(Rectangle().fill(Color.App.separator).frame(height: 1), alignment: .bottom)
                
                HStack(spacing: 0) {
                    tabButton(title: "财务知识", index: 0)
                    tabButton(title: "经典书籍", index: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.App.cardBackground)
                
                if selectedTab == 0 {
                    articlesList
                } else {
                    booksList
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? Color.App.darkGreen : Color.App.textSecondary)
                
                Rectangle()
                    .fill(selectedTab == index ? Color(hex: "#9EE0C8") : Color.clear)
                    .frame(height: 3)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var articlesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(financialArticles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        ArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    private var booksList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(classicBooks) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCard(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

struct Article: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let content: String
    let tag: String
    let category: String
    let readTime: Int
    let level: String
    let paragraphs: [String]
}

struct BookSummary: Identifiable {
    let id = UUID()
    let cover: String
    let title: String
    let author: String
    let summary: String
    let keyPoints: [String]
    let category: String
    let readTime: Int
    let level: String
    let paragraphs: [String]
}

struct ArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(article.icon)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Color.App.lightGreen.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(article.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text(article.tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.App.darkGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.App.primaryGreen.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    Text(article.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.App.textSecondary)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Label("\(article.readTime) 分钟", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color.App.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Text("阅读全文")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color.App.darkGreen)
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

struct BookCard: View {
    let book: BookSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Text(book.cover)
                    .font(.system(size: 36))
                    .frame(width: 52, height: 68)
                    .background(Color.App.lightYellow.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.textSecondary)
                    Text(book.summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color.App.darkGreen)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Label("\(book.readTime) 分钟", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color.App.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Text("查看精读")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color.App.darkGreen)
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationView {
        FinancialAcademyView()
    }
}
