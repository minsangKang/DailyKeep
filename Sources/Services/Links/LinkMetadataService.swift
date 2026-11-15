import Foundation
import LinkPresentation
import UniformTypeIdentifiers

/// 링크의 제목과 대표 이미지를 가져와 썸네일로 저장합니다.
enum LinkMetadataService {
    static func fetch(into bookmark: Bookmark) async {
        guard let url = bookmark.url else { return }
        let provider = LPMetadataProvider()
        provider.timeout = 15
        defer { bookmark.metadataFetched = true }
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }

        if let title = metadata.title?.nonEmpty, bookmark.title == url.host() || bookmark.title.isEmpty {
            bookmark.title = title
        }
        bookmark.siteName = bookmark.host
        if let itemProvider = metadata.imageProvider ?? metadata.iconProvider,
           let data = await loadImageData(itemProvider) {
            bookmark.thumbnail = ImageUtil.downscaledJPEG(data, maxPixel: 240)
        }
        bookmark.touch()
    }

    private static func loadImageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// 사용자가 붙여넣은 글자에서 URL을 찾습니다. 스킴이 없으면 https를 붙입니다.
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let url = match.url {
            return url
        }
        guard !trimmed.contains(" "), trimmed.contains(".") else { return nil }
        return URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
    }
}
