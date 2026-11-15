import SwiftUI

/// 한 줄 입력 + Return 저장. 저장 후에도 포커스를 유지해 연달아 적을 수 있습니다.
struct QuickAddBar: View {
    let placeholder: String
    var systemImage = "plus"
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(submit)
            if !text.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.bar, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08)))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.snappy(duration: 0.2), value: text.isEmpty)
    }

    private func submit() {
        guard let value = text.nonEmpty else { return }
        onSubmit(value)
        text = ""
        focused = true
    }
}
