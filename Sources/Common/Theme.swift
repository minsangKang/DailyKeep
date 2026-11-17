import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init?(data: Data?) {
        guard let data, let image = PlatformImage(data: data) else { return nil }
        #if os(iOS)
        self.init(uiImage: image)
        #else
        self.init(nsImage: image)
        #endif
    }
}

extension View {
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func noAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }
}

extension ToolbarItemPlacement {
    static var trailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

extension Date {
    var shortDay: String { formatted(.dateTime.month().day()) }
    var dayWithWeekday: String { formatted(.dateTime.month().day().weekday(.abbreviated)) }
    var relativeShort: String {
        Calendar.current.isDateInToday(self) ? formatted(.dateTime.hour().minute()) : shortDay
    }
}

/// 흑백 칩. 선택되면 반전됩니다.
struct Chip: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.platformBackground : Color.primary)
            .background(isSelected ? Color.primary : Color.clear, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.2)))
            .contentShape(.capsule)
    }
}

extension Color {
    static var platformBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

/// 행 아래 붙는 작은 "#카테고리" 목록
struct CategoryTags: View {
    let categories: [ItemCategory]

    var body: some View {
        if !categories.isEmpty {
            Text(categories.map { "#\($0.name)" }.joined(separator: " "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// 상세 화면 하단의 날짜 메타정보
struct MetaFooter<Item: KeepItem>: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("만든 날 \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Text("고친 날 \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension View {
    /// 목록이 비었을 때 안내를 화면 가운데에 띄웁니다.
    /// 맥에선 빈 List가 내용 크기로 줄어들어 안내가 위로 붙기 때문에, 목록과 안내 모두 칸을 꽉 채웁니다.
    func emptyState<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}

extension Color {
    /// 토글 켜짐 색. 라이트는 검정, 다크는 중간 회색(#8E8E93)이라 흰 손잡이와 구분됩니다.
    static let toggleTint = Color("ToggleTint")
}

extension View {
    /// 흑백 테마에서 켜짐/꺼짐이 구분되는 토글
    func monochromeToggle() -> some View {
        tint(.toggleTint)
    }
}
