import SwiftData
import SwiftUI

struct WordDetailView: View {
    @Bindable var word: Word
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EnrichmentService.self) private var enrichment

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("단어", text: $word.title)
                        .font(.largeTitle.bold())
                    Text([word.partOfSpeech, word.pronunciation].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
                CategoriesField(item: word)
            }

            if word.aiStatus == .pending {
                Section { HStack { ProgressView(); Text("AI가 정리하는 중…").foregroundStyle(.secondary) } }
            } else if word.aiStatus == .failed {
                Section("AI 정리 실패") { Text(word.aiError).foregroundStyle(.secondary) }
            }

            Section("뜻") {
                TextField("뜻", text: $word.meaning, axis: .vertical)
            }

            if !word.examples.isEmpty {
                Section("예문") {
                    ForEach(word.examples, id: \.self) { example in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.sentence)
                            Text(example.translation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                }
            }

            if !word.synonyms.isEmpty {
                Section("비슷한 말") {
                    Text(word.synonyms.joined(separator: ", ")).textSelection(.enabled)
                }
            }

            if !word.usageNote.isEmpty {
                Section("이렇게 써요") {
                    Text(word.usageNote).textSelection(.enabled)
                }
            }

            Section("메모") {
                TextField("직접 남길 메모", text: $word.memo, axis: .vertical)
            }

            Section {
                MetaFooter(item: word)
                if !word.aiProvider.isEmpty {
                    Text("AI: \(word.aiProvider)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(word.title)
        .inlineTitle()
        .onChange(of: word.title) { word.touch() }
        .onChange(of: word.meaning) { word.touch() }
        .onChange(of: word.memo) { word.touch() }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Menu {
                    Button("AI로 다시 정리", systemImage: "sparkles") { enrichment.enrich(word) }
                    Button("삭제", systemImage: "trash", role: .destructive) {
                        context.delete(word)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}
