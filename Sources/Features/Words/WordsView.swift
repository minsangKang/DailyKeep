import SwiftData
import SwiftUI

/// 단어 탭: ArrangementView(overlay) — 주 뷰(전경)는 빠른 입력 패널, 보조 뷰(배경)는 단어 목록.
struct WordsView: View {
    @Query(sort: \Word.createdAt, order: .reverse) private var words: [Word]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var categoryID: UUID?

    private var filtered: [Word] {
        SearchEngine.filter(words, query: query, categoryIDs: categoryID.map { [$0] } ?? [])
    }

    private var currentCategory: ItemCategory? {
        words.usedCategories.first { $0.id == categoryID }
    }

    var body: some View {
        Arranged(.overlay) {
            WordCaptureView(category: currentCategory)
        } secondary: {
            List {
                CategoryFilterBar(categories: words.usedCategories, selection: $categoryID)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                ForEach(filtered) { word in
                    NavigationLink(value: word) { WordRow(word: word) }
                }
                .onDelete { offsets in offsets.map { filtered[$0] }.forEach(context.delete) }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, 96, for: .scrollContent)
            .emptyState {
                if words.isEmpty {
                    ContentUnavailableView("모르는 단어를 적어두세요", systemImage: "character.book.closed",
                                           description: Text("뜻과 예문은 AI가 채워 둡니다."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("단어")
        .searchable(text: $query, prompt: "단어, 뜻, 카테고리")
        .navigationDestination(for: Word.self) { WordDetailView(word: $0) }
        .settingsToolbar()
    }
}

struct WordRow: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.title).font(.headline)
                if !word.partOfSpeech.isEmpty {
                    Text(word.partOfSpeech).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                AIStatusBadge(status: word.aiStatus)
            }
            if let meaning = word.meaning.nonEmpty {
                Text(meaning).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            CategoryTags(categories: word.categoryList)
        }
        .padding(.vertical, 2)
    }
}

struct AIStatusBadge: View {
    let status: AIStatus

    var body: some View {
        switch status {
        case .pending: ProgressView().controlSize(.small)
        case .failed: Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary)
        case .none, .done: EmptyView()
        }
    }
}
