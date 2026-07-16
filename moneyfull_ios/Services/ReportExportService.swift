import SwiftUI
import UIKit

enum ExportError: LocalizedError {
    case renderFailed
    var errorDescription: String? { "报告渲染失败，请重试" }
}

/// 报告导出服务
@MainActor
struct ReportExportService {

    /// 导出为图片（ImageRenderer, 3x）
    static func exportAsImage(
        project: Project,
        reviewResult: ProjectReviewResult,
        projectMode: ProjectMode
    ) -> UIImage? {
        let reportView = ProjectReviewReportView(
            project: project,
            reviewResult: reviewResult,
            projectMode: projectMode
        )
        let renderer = ImageRenderer(content: reportView)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// 导出为 PDF
    static func exportAsPDF(
        project: Project,
        reviewResult: ProjectReviewResult,
        projectMode: ProjectMode
    ) -> Data? {
        guard let image = exportAsImage(project: project, reviewResult: reviewResult, projectMode: projectMode) else {
            return nil
        }
        let pageRect = CGRect(origin: .zero, size: image.size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(at: .zero)
        }
    }

    /// 获取图片用于分享（不再直接保存到相册）
    static func prepareForShare(_ image: UIImage) -> UIImage {
        return image
    }

    /// 保存到临时文件
    static func saveToFile(_ data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
}
