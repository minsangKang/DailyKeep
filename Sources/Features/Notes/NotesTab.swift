import SwiftUI

/// 메모 탭: 할 일과 위키를 위쪽 세그먼트로 오가며 씁니다. 마지막으로 본 쪽을 기억합니다.
struct NotesTab: View {
    enum Mode: String, CaseIterable {
        case todo, wiki

        var label: String {
            switch self {
            case .todo: ItemKind.todo.label
            case .wiki: ItemKind.wiki.label
            }
        }
    }

    @AppStorage("notesMode") private var mode = Mode.todo

    var body: some View {
        Group {
            switch mode {
            case .todo: TodoTab()
            case .wiki: WikiListView()
            }
        }
        .navigationTitle("메모")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("메모", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.label) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .settingsToolbar()
    }
}
