import SwiftData
import SwiftUI

/// 네 종류를 한 번에 찾는 검색. 토큰 = 카테고리, 범위 = 종류.
struct GlobalSearchView: View {
    @Query(sort: \ItemCategory.name) private var categories: [ItemCategory]
    @Query(sort: \Word.updatedAt, order: .reverse) private var words: [Word]
    @Query(sort: \TodoItem.updatedAt, order: .reverse) private var todos: [TodoItem]
    @Query(sort: \WikiNote.updatedAt, order: .reverse) private var notes: [WikiNote]
    @Query(sort: \Bookmark.updatedAt, order: .reverse) private var bookmarks: [Bookmark]
    @Environment(\.openURL) private var openURL

    @State private var query = ""
    @State private var tokens: [ItemCategory] = []
    @State private var scope: ItemKind?
    @State private var editing: Bookmark?

    private var tokenIDs: Set<UUID> { Set(tokens.map(\.id)) }
    private var isIdle: Bool { query.nonEmpty == nil && tokens.isEmpty }

    private func include(_ kind: ItemKind) -> Bool { scope == nil || scope == kind }

    var body: some View {
        List {
            if isIdle {
                categoryDirectory
            } else {
                results
            }
        }
        .listStyle(.plain)
        .emptyState { emptyState }
        .navigationTitle("검색")
        .searchable(text: $query, tokens: $tokens, suggestedTokens: .constant(suggestions), prompt: "전체 검색 · #카테고리") { token in
            Label(token.name, systemImage: "number")
        }
        .searchScopes($scope) {
            Text("전체").tag(ItemKind?.none)
            ForEach(ItemKind.allCases) { Text($0.label).tag(ItemKind?.some($0)) }
        }
        .navigationDestination(for: Word.self) { WordDetailView(word: $0) }
        .navigationDestination(for: TodoItem.self) { TodoDetailView(todo: $0) }
        .navigationDestination(for: WikiNote.self) { WikiEditorView(note: $0) }
        .sheet(item: $editing) { BookmarkEditor(bookmark: $0) }
        .settingsToolbar()
    }

    private var suggestions: [ItemCategory] {
        let available = categories.filter { !tokenIDs.contains($0.id) }
        guard let text = query.nonEmpty?.trimmingCharacters(in: CharacterSet(charactersIn: "#")), !text.isEmpty else { return available }
        return available.filter { $0.name.localizedStandardContains(text) }
    }

    /// 검색어가 없을 때: 카테고리별로 둘러보기
    @ViewBuilder
    private var categoryDirectory: some View {
        if !categories.isEmpty {
            Section("카테고리") {
                ForEach(categories) { category in
                    Button {
                        tokens = [category]
                    } label: {
                        HStack {
                            Label(category.name, systemImage: "number")
                            Spacer()
                            Text("\(category.itemCount)").foregroundStyle(.secondary).monospacedDigit()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var foundWords: [Word] { include(.word) ? SearchEngine.filter(words, query: query, categoryIDs: tokenIDs) : [] }
    private var foundTodos: [TodoItem] { include(.todo) ? SearchEngine.filter(todos, query: query, categoryIDs: tokenIDs) : [] }
    private var foundNotes: [WikiNote] { include(.wiki) ? SearchEngine.filter(notes, query: query, categoryIDs: tokenIDs) : [] }
    private var foundLinks: [Bookmark] { include(.link) ? SearchEngine.filter(bookmarks, query: query, categoryIDs: tokenIDs) : [] }

    /// 빈 화면 안내는 다른 탭처럼 List 위 overlay로 가운데에 둡니다.
    @ViewBuilder
    private var emptyState: some View {
        if isIdle && categories.isEmpty {
            ContentUnavailableView("모든 것을 한 번에 찾아요", systemImage: "magnifyingglass",
                                   description: Text("단어, 할 일, 위키, 링크를 제목·내용·카테고리로 찾습니다."))
        } else if !isIdle && foundWords.isEmpty && foundTodos.isEmpty && foundNotes.isEmpty && foundLinks.isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }

    @ViewBuilder
    private var results: some View {
        let foundWords = foundWords
        let foundTodos = foundTodos
        let foundNotes = foundNotes
        let foundLinks = foundLinks

        if !foundWords.isEmpty {
            Section(ItemKind.word.label) {
                ForEach(foundWords) { word in NavigationLink(value: word) { WordRow(word: word) } }
            }
        }
        if !foundTodos.isEmpty {
            Section(ItemKind.todo.label) {
                ForEach(foundTodos) { todo in NavigationLink(value: todo) { TodoRow(todo: todo) } }
            }
        }
        if !foundNotes.isEmpty {
            Section(ItemKind.wiki.label) {
                ForEach(foundNotes) { note in NavigationLink(value: note) { WikiRow(note: note) } }
            }
        }
        if !foundLinks.isEmpty {
            Section(ItemKind.link.label) {
                ForEach(foundLinks) { bookmark in
                    Button {
                        if let url = bookmark.url { openURL(url) }
                    } label: { LinkRow(bookmark: bookmark) }
                    .buttonStyle(.plain)
                    .contextMenu { Button("편집", systemImage: "pencil") { editing = bookmark } }
                }
            }
        }
    }
}
