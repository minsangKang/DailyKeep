import Foundation
import SwiftData
import Testing
@testable import DailyKeep

@MainActor
struct SearchEngineTests {
    let container = ModelContainerFactory.make(inMemory: true)

    @Test func matchesTitleBodyAndCategoryName() throws {
        let context = container.mainContext
        let travel = ItemCategory(name: "여행")
        context.insert(travel)
        let word = Word(title: "serendipity")
        word.meaning = "뜻밖의 행운"
        word.categories = [travel]
        let other = Word(title: "apple")
        context.insert(word)
        context.insert(other)

        let words = [word, other]
        #expect(SearchEngine.filter(words, query: "seren") == [word])
        #expect(SearchEngine.filter(words, query: "행운") == [word])
        #expect(SearchEngine.filter(words, query: "#여행") == [word])
        #expect(SearchEngine.filter(words, query: "여행 행운") == [word])
        #expect(SearchEngine.filter(words, query: "여행 banana").isEmpty)
        #expect(SearchEngine.filter(words, query: "", categoryIDs: [travel.id]) == [word])
        #expect(SearchEngine.filter(words, query: "").count == 2)
    }
}

struct MarkdownTests {
    @Test func frontMatterRoundTrip() {
        var file = MarkdownFile()
        file.set("title", "따옴표 \"와\" 콜론: 포함")
        file.set("tags", ["a", "b"])
        file.set("done", true)
        file.set("due", nil)
        file.body = "# 본문\n\n---\n두 번째 줄"

        let decoded = MarkdownFile.decode(file.encoded())
        #expect(decoded.string("title") == "따옴표 \"와\" 콜론: 포함")
        #expect(decoded.strings("tags") == ["a", "b"])
        #expect(decoded.bool("done"))
        #expect(decoded["due"] is NSNull)
        #expect(decoded.body == file.body)
    }

    @Test func parsesBlocks() {
        let blocks = MarkdownBlock.parse("# 제목\n\n문단\n- 항목\n- [x] 끝\n1. 첫째\n> 인용\n![](assets/a.jpg)")
        #expect(blocks == [
            .heading(1, "제목"), .paragraph("문단"), .bullet("항목", checked: nil), .bullet("끝", checked: true),
            .numbered(1, "첫째"), .quote("인용"), .image("assets/a.jpg"),
        ])
    }

    @Test func slugKeepsHangul() {
        #expect(BackupService.slug("오늘 배운 것: Swift!") == "오늘-배운-것-swift")
        #expect(BackupService.slug("???") == "untitled")
    }
}
