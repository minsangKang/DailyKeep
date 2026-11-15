import SwiftUI

enum ArrangementKind {
    /// 나란히. 넓으면 좌우, 높으면 위아래.
    case split
    /// 좌우로만 나눕니다. 세로로 긴 화면에선 주 뷰만 남습니다.
    case splitHorizontal
    /// 주 뷰(전경)를 보조 뷰(배경) 위에 겹칩니다. 기기를 접으면 나란히 놓입니다.
    case overlay
}

/// 탐색 컨테이너(NavigationStack)와 콘텐츠 컨테이너(List/ScrollView) 사이에 두는 배열 컨테이너.
/// iOS는 iOS 27.1 `ArrangementView`, macOS(27.0 SDK에 아직 없음)는 같은 의도의 폴백(HStack/하단 고정)을 씁니다.
struct Arranged<Primary: View, Secondary: View>: View {
    private let kind: ArrangementKind
    private let primary: Primary
    private let secondary: Secondary

    init(_ kind: ArrangementKind, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.kind = kind
        self.primary = primary()
        self.secondary = secondary()
    }

    #if os(iOS)
    @State private var size: CGSize = .zero

    @ViewBuilder
    private var arranged: some View {
        let view = ArrangementView { primary } secondary: { secondary }
        switch kind {
        case .split: view.arrangementViewStyle(.split)
        case .splitHorizontal: view.arrangementViewStyle(.split.axes(.horizontal))
        case .overlay: view.arrangementViewStyle(.overlay)
        }
    }
    #endif

    var body: some View {
        #if os(iOS)
        arranged
            .environment(\.arrangementSize, size)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        #else
        switch kind {
        case .split, .splitHorizontal:
            // HSplitView(NSSplitView)는 창 크기를 바꿀 때 SwiftUI 내용과 서로 크기를 맞추다
            // 레이아웃 반복으로 앱이 종료돼서, 순수 SwiftUI로 반씩 나눕니다.
            HStack(spacing: 0) {
                primary.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                secondary.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .overlay:
            secondary.safeAreaInset(edge: .bottom, spacing: 0) { primary }
        }
        #endif
    }
}

extension View {
    /// overlay에서 이 뷰가 다른 뷰 위에 겹쳐 있으면 true, 나란히 놓이면 false를 넘깁니다.
    /// `overlayArrangementZIndex`와 함께, 이 뷰가 차지한 칸이 배열 전체를 덮는지도 봅니다
    /// (27.1 베타에선 펼친 화면에서도 zIndex가 0으로 와서 크기로 보완합니다).
    /// 이 수정자를 붙인 뷰는 배열이 준 칸을 꽉 채워야 합니다. macOS 폴백은 항상 겹친 상태입니다.
    func readingOverlayCollapsed(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(OverlayCollapseReader(action: action))
    }
}

private struct ArrangementSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    /// Arranged 전체 크기
    var arrangementSize: CGSize {
        get { self[ArrangementSizeKey.self] }
        set { self[ArrangementSizeKey.self] = newValue }
    }
}

private struct OverlayCollapseReader: ViewModifier {
    let action: (Bool) -> Void
    #if os(iOS)
    @Environment(\.overlayArrangementZIndex) private var zIndex
    @Environment(\.arrangementSize) private var total
    @State private var slot: CGSize = .zero

    private var collapsed: Bool {
        if zIndex > 0 { return true }
        guard total.width > 0, slot.width > 0 else { return true }
        return slot.width > total.width * 0.8 && slot.height > total.height * 0.8
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { slot = $0 }
            .onChange(of: collapsed, initial: true) { _, value in action(value) }
    }
    #else
    func body(content: Content) -> some View {
        content.onAppear { action(true) }
    }
    #endif
}
