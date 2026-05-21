import Vision
import UIKit

class VisionService {
    static let shared = VisionService()
    
    private init() {}
    
    /// 从图片中提取文本
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: VisionError.noResults)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            // 配置识别参数
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en"] // 支持中文和英文
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 从图片中提取文本并清理
    func extractCleanText(from image: UIImage) async throws -> String {
        let rawText = try await recognizeText(from: image)
        return cleanOCRText(rawText)
    }
    
    /// 清理OCR提取的文本
    private func cleanOCRText(_ text: String) -> String {
        var cleaned = text
        
        // 移除多余的空白行
        cleaned = cleaned.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
        
        // 常见的OCR错误修正
        let replacements: [String: String] = [
            "¥": "¥",
            "￥": "¥",
            "元": "元",
            "圆": "元"
        ]
        
        for (old, new) in replacements {
            cleaned = cleaned.replacingOccurrences(of: old, with: new)
        }
        
        return cleaned
    }
}

enum VisionError: Error {
    case invalidImage
    case noResults
    case recognitionFailed
}