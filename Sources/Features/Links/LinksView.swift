import SwiftData
import SwiftUI

struct LinksView: View {
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var clipboard = ClipboardWatcher()
    @State private var query = ""
    @State private var categoryID: UUID?
    @State private var adding = false
    @State private var editing: Bookmark?
    @State private var notice: String?

    private var filtered: [Bookmark] {
        SearchEngine.filter(bookmarks, query: query, categoryIDs: categoryID.map { [$0] } ?? [])
    }

    var body: some View {
        List {
            CategoryFilterBar(categories: bookmarks.usedCategories, selection: $categoryID)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            ForEach(filtered) { bookmark in
                Button {
                    if let url = bookmark.url { openURL(url) }
                } label: {
                    LinkRow(bookmark: bookmark)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: bookmark) }
                .swipeActions(edge: .trailing) {
                    Button("삭제", systemImage: "trash", role: .destructive) { context.delete(bookmark) }
                    Button("편집", systemImage: "pencil") { editing = bookmark }
                }
            }
        }
        .listStyle(.plain)
        .emptyState {
            if bookmarks.isEmpty {
                ContentUnavailableView("링크를 모아두세요", systemImage: "link",
                                       description: Text("다른 앱에서 링크를 복사하고 이 화면으로 오면 바로 붙여넣을 수 있어요."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if clipboard.hasNewURL {
                PasteBanner(onPaste: add(urls:), onDismiss: clipboard.markHandled)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let notice {
                Text(notice).font(.footnote).foregroundStyle(.secondary).padding(8)
            }
        }
        .animation(.snappy, value: clipboard.hasNewURL)
        .navigationTitle("링크")
        .searchable(text: $query, prompt: "제목, 주소, 카테고리")
        .settingsToolbar()
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Button("링크 추가", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { AddLinkSheet(onAdd: { add(urls: [$0]) }) }
        .sheet(item: $editing) { BookmarkEditor(bookmark: $0) }
        .task { await clipboard.check() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await clipboard.check() } }
        }
        .task(id: bookmarks.filter { !$0.metadataFetched }.count) {
            for bookmark in bookmarks where !bookmark.metadataFetched {
                await LinkMetadataService.fetch(into: bookmark)
            }
        }
    }

    @ViewBuilder
    private func menu(for bookmark: Bookmark) -> some View {
        if let url = bookmark.url {
            ShareLink(item: url)
        }
        Button("주소 복사", systemImage: "doc.on.doc") {
            #if os(iOS)
            UIPasteboard.general.string = bookmark.urlString
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(bookmark.urlString, forType: .string)
            #endif
            clipboard.markHandled()
        }
        Button("편집", systemImage: "pencil") { editing = bookmark }
        Button("섬네일 다시 가져오기", systemImage: "arrow.clockwise") { bookmark.metadataFetched = false }
        Button("삭제", systemImage: "trash", role: .destructive) { context.delete(bookmark) }
    }

    private func add(urls: [URL]) {
        clipboard.markHandled()
        for url in urls {
            if bookmarks.contains(where: { $0.urlString == url.absoluteString }) {
                notice = "이미 저장된 링크예요"
                continue
            }
            let bookmark = Bookmark(url: url)
            if let category = bookmarks.usedCategories.first(where: { $0.id == categoryID }) {
                bookmark.categories = [category]
            }
            context.insert(bookmark)
            notice = nil
        }
    }
}

/// "복사한 링크를 붙여넣을까요?" — PasteButton이라 시스템 허용 팝업 없이 한 번에 붙여넣습니다.
private struct PasteBanner: View {
    let onPaste: ([URL]) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
            Text("복사한 링크를 붙여넣을까요?").font(.subheadline)
            Spacer()
            PasteButton(payloadType: URL.self) { urls in
                Task { @MainActor in onPaste(urls) }
            }
            .labelStyle(.titleOnly)
            .buttonBorderShape(.capsule)
            .tint(.primary)
            Button("닫기", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.1)))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct LinkRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = Image(data: bookmark.thumbnail) {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.primary.opacity(0.06)
                        if bookmark.metadataFetched {
                            Image(systemName: "link").foregroundStyle(.secondary)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(bookmark.title).font(.headline).lineLimit(2)
                HStack(spacing: 6) {
                    Text(bookmark.host)
                    Text("·")
                    Text(bookmark.createdAt.shortDay)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                CategoryTags(categories: bookmark.categoryList)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

private struct AddLinkSheet: View {
    let onAdd: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("https://", text: $text)
                    .noAutocapitalization()
                    #if os(iOS)
                    .keyboardType(.URL)
                    #endif
                    .onSubmit(save)
            }
            .navigationTitle("링크 추가")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가", action: save).disabled(LinkMetadataService.url(from: text) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let url = LinkMetadataService.url(from: text) else { return }
        onAdd(url)
        dismiss()
    }
}

struct BookmarkEditor: View {
    @Bindable var bookmark: Bookmark
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("제목", text: $bookmark.title, axis: .vertical)
                    TextField("주소", text: $bookmark.urlString).noAutocapitalization()
                    CategoriesField(item: bookmark)
                }
                Section("메모") {
                    TextField("메모", text: $bookmark.note, axis: .vertical)
                }
                Section { MetaFooter(item: bookmark) }
            }
            .navigationTitle("링크")
            .inlineTitle()
            .onChange(of: bookmark.title) { bookmark.touch() }
            .onChange(of: bookmark.note) { bookmark.touch() }
            .onChange(of: bookmark.urlString) { bookmark.metadataFetched = false }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
    }
}
