import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0
    
    private var headerOpacity: Double {
        min(1, max(0, scrollOffset / 80))
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#FAFBFA").ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: 0)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        articleHeader
                        articleMeta
                        Divider().background(Color(hex: "#E1E3E2"))
                        articleBody
                        bottomTip
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = -value
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var headerBar: some View {
        ZStack {
            Color.white
                .opacity(headerOpacity)
                .background(.ultraThinMaterial.opacity(headerOpacity))
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#276956"))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                Spacer()
                if headerOpacity > 0.5 {
                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#1A3C2E"))
                        .lineLimit(1)
                        .transition(.opacity)
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
        .animation(.easeInOut(duration: 0.15), value: headerOpacity > 0.5)
    }
    
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(article.icon)
                    .font(.system(size: 36))
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "#F0FBF6"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.tag)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#276956"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#9EE0C8").opacity(0.3))
                        .clipShape(Capsule())
                    Text(article.category)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                }
            }
            
            Text(article.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "#1A3C2E"))
                .lineSpacing(4)
            
            Text(article.subtitle)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A7A6A"))
                .lineSpacing(4)
        }
        .padding(.top, 8)
    }
    
    private var articleMeta: some View {
        HStack(spacing: 16) {
            Label("阅读约 \(article.readTime) 分钟", systemImage: "clock")
            Label(article.level, systemImage: "chart.bar")
        }
        .font(.system(size: 12))
        .foregroundColor(Color.gray)
    }
    
    private var articleBody: some View {
        NoticeParagraphRenderer(paragraphs: article.paragraphs)
    }
    
    private var bottomTip: some View {
        VStack(spacing: 12) {
            Divider().background(Color(hex: "#E1E3E2"))
            
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "#F5C542"))
                Text("小贴士：将学到的知识应用到日常记账中，才能真正提升财商")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FFFDE7"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 8)
    }
}

struct BookDetailView: View {
    let book: BookSummary
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0
    
    private var headerOpacity: Double {
        min(1, max(0, scrollOffset / 80))
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#FAFBFA").ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("scrollBook")).minY
                        )
                    }
                    .frame(height: 0)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        bookHeader
                        bookMeta
                        Divider().background(Color(hex: "#E1E3E2"))
                        bookBody
                        keyPointsSection
                        bottomTip
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: "scrollBook")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = -value
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var headerBar: some View {
        ZStack {
            Color.white
                .opacity(headerOpacity)
                .background(.ultraThinMaterial.opacity(headerOpacity))
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#276956"))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                Spacer()
                if headerOpacity > 0.5 {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#1A3C2E"))
                        .lineLimit(1)
                        .transition(.opacity)
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
        .animation(.easeInOut(duration: 0.15), value: headerOpacity > 0.5)
    }
    
    private var bookHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text(book.cover)
                    .font(.system(size: 44))
                    .frame(width: 72, height: 96)
                    .background(Color(hex: "#FFF8E1"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 2, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#1A3C2E"))
                        .lineSpacing(2)
                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundColor(Color.gray)
                    Text(book.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#276956"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#9EE0C8").opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            
            Text(book.summary)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A7A6A"))
                .lineSpacing(5)
        }
        .padding(.top, 8)
    }
    
    private var bookMeta: some View {
        HStack(spacing: 16) {
            Label("阅读约 \(book.readTime) 分钟", systemImage: "clock")
            Label(book.level, systemImage: "chart.bar")
        }
        .font(.system(size: 12))
        .foregroundColor(Color.gray)
    }
    
    private var bookBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("📖 书籍精读")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#226552"))
            
            ForEach(book.paragraphs.indices, id: \.self) { index in
                let para = book.paragraphs[index]
                if para.hasPrefix("## ") {
                    Text(String(para.dropFirst(3)))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#226552"))
                        .padding(.top, 4)
                } else if para.hasPrefix("• ") {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(hex: "#9EE0C8"))
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(String(para.dropFirst(2)))
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#3A3A3A"))
                            .lineSpacing(6)
                    }
                } else {
                    Text(para)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#3A3A3A"))
                        .lineSpacing(7)
                }
            }
        }
    }
    
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("💡 核心要点")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#226552"))
            
            ForEach(book.keyPoints.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color(hex: "#276956"))
                        .clipShape(Circle())
                    Text(book.keyPoints[i])
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#3A3A3A"))
                        .lineSpacing(5)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#F0FBF6"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var bottomTip: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "#F5C542"))
                Text("小贴士：读完后试着用记账 App 实践书中的理财方法")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FFFDE7"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
