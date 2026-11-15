import Foundation
import SwiftData
import Testing
@testable import DailyKeep

@MainActor
struct BackupTests {
    @Test func exportThenImportRestoresEverything() throws {
        let sourceContainer = ModelContainerFactory.make(inMemory: true)
        let source = sourceContainer.mainContext
        let study = ItemCategory(name: "공부")
        let shopping = ItemCategory(name: "쇼핑")
        source.insert(study)
        source.insert(shopping)

        let word = Word(title: "ubiquitous")
        word.meaning = "어디에나 있는"
        word.examples = [WordExample(sentence: "Phones are ubiquitous.", translation: "휴대폰은 어디에나 있다.")]
        word.synonyms = ["omnipresent"]
        word.categories = [study]
        source.insert(word)

        let todo = TodoItem(title: "장보기", dueDate: Date(timeIntervalSince1970: 1_800_000_000))
        todo.categories = [shopping, study]
        source.insert(todo)

        let note = WikiNote(title: "SwiftData 메모", body: "# 배운 것\n\n![](assets/x.jpg)")
        source.insert(note)
        let image = WikiImage(data: Data([0xFF, 0xD8, 0x01]))
        source.insert(image)
        image.note = note
        note.body = "# 배운 것\n\n![](\(image.assetPath))"

        let bookmark = Bookmark(url: URL(string: "https://example.com/item")!)
        bookmark.title = "갖고 싶은 것"
        bookmark.thumbnail = Data([1, 2, 3])
        bookmark.categories = [shopping]
        source.insert(bookmark)
        try source.save()

        let wrapper = try BackupService.makeBackup(from: source)
        let files = try #require(wrapper.fileWrappers)
        #expect(files["index.json"] != nil)
        #expect(Set(files.keys) == ["index.json", "words", "todos", "wiki", "links"])
        #expect(files["wiki"]?.fileWrappers?["assets"]?.fileWrappers?[image.fileName] != nil)

        let wordFile = try #require(files["words"]?.fileWrappers?.values.first?.regularFileContents)
        let wordText = String(decoding: wordFile, as: UTF8.self)
        #expect(wordText.hasPrefix("---\nid: \"\(word.id.uuidString)\""))
        #expect(wordText.contains("## 뜻\n\n어디에나 있는"))

        let targetContainer = ModelContainerFactory.make(inMemory: true)
        let target = targetContainer.mainContext
        let summary = try BackupService.restore(from: wrapper, into: target)
        #expect(summary.created == 4)

        let restoredWord = try #require(try target.fetch(FetchDescriptor<Word>()).first)
        #expect(restoredWord.id == word.id)
        #expect(restoredWord.examples == word.examples)
        #expect(restoredWord.categoryList.map(\.name) == ["공부"])

        let restoredTodo = try #require(try target.fetch(FetchDescriptor<TodoItem>()).first)
        #expect(restoredTodo.dueDate == todo.dueDate)
        #expect(Set(restoredTodo.categoryList.map(\.name)) == ["공부", "쇼핑"])

        let restoredNote = try #require(try target.fetch(FetchDescriptor<WikiNote>()).first)
        #expect(restoredNote.body == note.body)
        #expect(restoredNote.image(for: image.assetPath)?.data == image.data)

        let restoredLink = try #require(try target.fetch(FetchDescriptor<Bookmark>()).first)
        #expect(restoredLink.thumbnail == bookmark.thumbnail)
        #expect(restoredLink.title == "갖고 싶은 것")
        #expect(try target.fetch(FetchDescriptor<ItemCategory>()).count == 2)

        // 다시 가져오면 바뀐 게 없으니 모두 그대로
        let again = try BackupService.restore(from: wrapper, into: target)
        #expect(again.created == 0 && again.updated == 0 && again.skipped == 4)
    }
}
