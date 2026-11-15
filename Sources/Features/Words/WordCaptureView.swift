import SwiftData
import SwiftUI

/// 단어 탭의 주 뷰(전경). 목록 위에 겹쳐 있으면 한 줄 입력, 기기를 접어 나란히 놓이면 최근 단어 카드까지 펼칩니다.
struct WordCaptureView: View {
    /// 목록에서 고른 카테고리가 있으면 새 단어에 자동으로 붙입니다.
    let category: ItemCategory?

    @Environment(\.modelContext) private var context
    @Environment(EnrichmentService.self) private var enrichment
    @Query(sort: \Word.createdAt, order: .reverse) private var words: [Word]
    @State private var collapsed = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !collapsed {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("빠른 입력").font(.title2.bold())
                        if let latest = words.first {
                            WordInsightCard(word: latest)
                        } else {
                            Text("단어를 적으면 뜻과 예문이 여기에 바로 보입니다.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            if let category {
                Text("#\(category.name)에 저장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 26)
                    .padding(.top, 4)
            }
            QuickAddBar(placeholder: "모르는 단어를 적어보세요", systemImage: "character.cursor.ibeam", onSubmit: add)
        }
        .readingOverlayCollapsed { collapsed = $0 }
        .animation(.snappy, value: collapsed)
    }

    private func add(_ term: String) {
        if let existing = words.first(where: { $0.title.caseInsensitiveCompare(term) == .orderedSame }) {
            existing.touch()
            return
        }
        let word = Word(title: term)
        if let category { word.categories = [category] }
        context.insert(word)
        enrichment.enrich(word)
    }
}

/// 뜻·발음·예문을 한 장으로 보여주는 카드(빠른 입력 패널과 상세 화면이 함께 씁니다)
struct WordInsightCard: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.title).font(.title3.bold())
                Text([word.partOfSpeech, word.pronunciation].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            switch word.aiStatus {
            case .pending:
                HStack { ProgressView().controlSize(.small); Text("AI가 정리하는 중…").foregroundStyle(.secondary) }
            case .failed:
                Text(word.aiError).font(.footnote).foregroundStyle(.secondary)
            default:
                if !word.meaning.isEmpty { Text(word.meaning) }
                ForEach(word.examples, id: \.self) { example in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.sentence).italic()
                        Text(example.translation).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12)))
    }
}
