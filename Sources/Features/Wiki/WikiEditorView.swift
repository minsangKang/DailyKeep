import PhotosUI
import SwiftData
import SwiftUI

/// ArrangementView(split, 가로만) — 주 뷰는 편집기, 보조 뷰는 미리보기.
/// 세로로 긴 화면에선 편집기만 남고, 툴바 버튼으로 미리보기를 엽니다.
struct WikiEditorView: View {
    @Bindable var note: WikiNote
    var focusTitle = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TextSelection?
    @State private var photo: PhotosPickerItem?
    @State private var ocrPhoto: PhotosPickerItem?
    @State private var totalWidth: CGFloat = 0
    @State private var editorWidth: CGFloat = 0
    @State private var showPreview = false
    @State private var working = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        Arranged(.splitHorizontal) {
            editor
        } secondary: {
            MarkdownPreview(note: note)
                .background(Color.primary.opacity(0.03))

        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { totalWidth = $0 }
        .navigationTitle(note.title.nonEmpty ?? "새 글")
        .inlineTitle()
        .onChange(of: note.title) { note.touch() }
        .onChange(of: note.body) { note.touch() }
        .onChange(of: photo) { _, item in Task { await insertPhoto(item) } }
        .onChange(of: ocrPhoto) { _, item in Task { await insertText(from: item) } }
        .onDisappear(perform: dropIfEmpty)
        .onAppear { if focusTitle { titleFocused = true } }
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                MarkdownPreview(note: note)
                    .navigationTitle("미리보기")
                    .inlineTitle()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { showPreview = false } } }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .trailing) {
                if working { ProgressView().controlSize(.small) }
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("사진 넣기", systemImage: "photo")
                }
                // 편집기가 전체 폭을 쓰면 미리보기는 숨은 상태(세로 화면)라 버튼으로 엽니다
                if editorWidth > totalWidth * 0.8 {
                    Button("미리보기", systemImage: "eye") { showPreview = true }
                }
                Menu {
                    PhotosPicker(selection: $ocrPhoto, matching: .images) {
                        Label("사진 속 글자 넣기", systemImage: "text.viewfinder")
                    }
                    Button("삭제", systemImage: "trash", role: .destructive) {
                        context.delete(note)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("제목", text: $note.title)
                .font(.title2.bold())
                .focused($titleFocused)
                .textFieldStyle(.plain)
            CategoriesField(item: note)
                .font(.subheadline)
            Divider()
            TextEditor(text: $note.body, selection: $selection)
                .font(.body)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if note.body.isEmpty {
                        Text("알게 된 것을 자유롭게 적어보세요. # 제목, - 목록, > 인용을 쓸 수 있어요.")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            MetaFooter(item: note)
        }
        .padding()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { editorWidth = $0 }
    }

    /// 커서 위치(없으면 끝)에 텍스트를 끼워 넣습니다.
    private func insert(_ snippet: String) {
        if case .selection(let range)? = selection?.indices,
           range.lowerBound >= note.body.startIndex, range.upperBound <= note.body.endIndex {
            note.body.replaceSubrange(range, with: snippet)
        } else {
            if !note.body.isEmpty && !note.body.hasSuffix("\n") { note.body += "\n" }
            note.body += snippet
        }
    }

    private func insertPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        working = true
        defer { working = false; photo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = ImageUtil.downscaledJPEG(data, maxPixel: 1600) else { return }
        let image = WikiImage(data: jpeg)
        context.insert(image)
        image.note = note
        insert("\n![](\(image.assetPath))\n")
    }

    private func insertText(from item: PhotosPickerItem?) async {
        guard let item else { return }
        working = true
        defer { working = false; ocrPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let text = try? await TextRecognizer.recognize(data), !text.isEmpty else { return }
        insert(text + "\n")
    }

    /// 아무것도 안 쓰고 나가면 빈 글을 남기지 않습니다.
    private func dropIfEmpty() {
        if note.title.nonEmpty == nil && note.body.nonEmpty == nil && (note.images ?? []).isEmpty {
            context.delete(note)
        }
    }
}
