import SwiftData
import SwiftUI

struct WikiListView: View {
    @Query(sort: \WikiNote.updatedAt, order: .reverse) private var notes: [WikiNote]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var categoryID: UUID?
    @State private var path: [WikiNote] = []

    private var filtered: [WikiNote] {
        SearchEngine.filter(notes, query: query, categoryIDs: categoryID.map { [$0] } ?? [])
    }

    var body: some View {
        List {
            CategoryFilterBar(categories: notes.usedCategories, selection: $categoryID)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            ForEach(filtered) { note in
                NavigationLink(value: note) { WikiRow(note: note) }
            }
            .onDelete { $0.map { filtered[$0] }.forEach(context.delete) }
        }
        .listStyle(.plain)
        .emptyState {
            if notes.isEmpty {
                ContentUnavailableView("알게 된 것을 적어두세요", systemImage: "book.pages",
                                       description: Text("오른쪽 위 버튼으로 새 글을 씁니다."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "제목, 내용, 카테고리")
        .navigationDestination(for: WikiNote.self) { WikiEditorView(note: $0) }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                NewNoteButton(category: notes.usedCategories.first { $0.id == categoryID })
            }
        }
    }
}

private struct NewNoteButton: View {
    let category: ItemCategory?
    @Environment(\.modelContext) private var context
    @State private var created: WikiNote?

    var body: some View {
        Button("새 글", systemImage: "square.and.pencil") {
            let note = WikiNote(title: "")
            if let category { note.categories = [category] }
            context.insert(note)
            created = note
        }
        .navigationDestination(item: $created) { WikiEditorView(note: $0, focusTitle: true) }
    }
}

struct WikiRow: View {
    let note: WikiNote

    private var snippet: String {
        note.body.split(separator: "\n").map(String.init)
            .first { !$0.hasPrefix("![") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "#>-* ")) ?? ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.nonEmpty ?? "제목 없음").font(.headline)
                if !snippet.isEmpty {
                    Text(snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text(note.updatedAt.relativeShort)
                    CategoryTags(categories: note.categoryList)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let image = Image(data: note.images?.first?.data) {
                image.resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.vertical, 2)
    }
}
