import SwiftUI

#if os(iOS)
import UIKit

extension View {
    /// 키보드가 떠 있을 때 화면 어디든 누르면 닫힙니다. 루트에 한 번만 붙이면 시트까지 포함해 모든 화면에 적용됩니다.
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}

/// 이 뷰가 올라간 UIWindow에 탭 제스처를 하나 달아 둡니다.
/// 같은 창에 뜨는 시트·메뉴도 함께 처리되고, 장면(창)마다 한 번씩만 설치됩니다.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window,
                  !(window.gestureRecognizers ?? []).contains(where: { $0 is KeyboardDismissTap }) else { return }
            window.addGestureRecognizer(KeyboardDismissTap())
        }
    }
}

private final class KeyboardDismissTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(dismiss))
        // 버튼·목록 같은 원래 동작은 그대로 두고, 키보드만 함께 닫습니다.
        cancelsTouchesInView = false
        delegate = self
    }

    @objc private func dismiss() {
        view?.endEditing(true)
    }

    /// 다른 입력칸을 눌러 옮겨 가는 경우엔 닫지 않습니다.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let view = current {
            if view is UITextField || view is UITextView || view is UISearchBar { return false }
            current = view.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
#else
extension View {
    /// 맥은 화면 키보드가 없어 필요하지 않습니다.
    func dismissesKeyboardOnTap() -> some View { self }
}
#endif
