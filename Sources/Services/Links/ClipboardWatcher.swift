import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// 클립보드에 URL이 있는지 '내용을 읽지 않고' 확인합니다. 그래서 시스템 붙여넣기 경고가 뜨지 않습니다.
/// 실제 붙여넣기는 배너의 PasteButton이 맡습니다.
@Observable
final class ClipboardWatcher {
    private static let handledKey = "handledPasteboardChangeCount"
    private(set) var hasNewURL = false

    private var changeCount: Int {
        #if os(iOS)
        UIPasteboard.general.changeCount
        #else
        NSPasteboard.general.changeCount
        #endif
    }

    func check() async {
        let current = changeCount
        guard current != UserDefaults.standard.integer(forKey: Self.handledKey) else {
            hasNewURL = false
            return
        }
        #if os(iOS)
        let pasteboard = UIPasteboard.general
        // hasURLs는 내용을 읽지 않아 경고가 없습니다(사파리 '링크 복사' 등).
        if pasteboard.hasURLs {
            hasNewURL = true
            return
        }
        guard pasteboard.hasStrings else { hasNewURL = false; return }
        let patterns: Set<PartialKeyPath<UIPasteboard.DetectedValues>> = [\.probableWebURL, \.links]
        let found = (try? await pasteboard.detectedPatterns(for: patterns)) ?? []
        hasNewURL = !found.isEmpty
        #else
        hasNewURL = NSPasteboard.general.availableType(from: [.URL]) != nil
        #endif
    }

    /// 붙여넣었거나 닫은 클립보드는 다시 묻지 않습니다.
    func markHandled() {
        UserDefaults.standard.set(changeCount, forKey: Self.handledKey)
        hasNewURL = false
    }
}
