import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 백업 폴더 구조
/// ```
/// index.json                  전체 구조: 카테고리, 항목 id·메타·파일 경로
/// words/<slug>-<id8>.md       항목마다 front matter + 본문
/// todos/… wiki/… links/…
/// wiki/assets/<uuid>.jpg      위키 사진(본문의 ![](assets/…)와 같은 상대 경로)
/// links/assets/<uuid>.jpg     링크 섬네일
/// meals/assets/<uuid>.jpg     식사 사진
/// expenses/…                  지출(사진 없음)
/// ```
struct BackupIndex: Codable {
    struct Category: Codable {
        var id: UUID
        var name: String
        var createdAt: Date
    }

    struct Item: Codable {
        var id: UUID
        var kind: ItemKind
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var categoryIds: [UUID]
        var file: String
    }

    var format = "dailykeep-backup"
    var version = 1
    var exportedAt: Date
    var categories: [Category]
    var items: [Item]
}

struct RestoreSummary: CustomStringConvertible {
    var created = 0
    var updated = 0
    var skipped = 0

    var description: String { "새로 \(created)개, 갱신 \(updated)개, 그대로 \(skipped)개" }
}

enum BackupError: LocalizedError {
    case missingIndex
    var errorDescription: String? { "index.json이 있는 Daily Keep 백업 폴더가 아닙니다." }
}

enum BackupService {
    static func defaultFolderName(now: Date = .now) -> String {
        "DailyKeep-Backup-\(now.formatted(.iso8601.year().month().day()))"
    }

    // MARK: 내보내기

    static func makeBackup(from context: ModelContext, now: Date = .now) throws -> FileWrapper {
        var folders: [String: [String: FileWrapper]] = [:]
        var items: [BackupIndex.Item] = []
        var usedNames = Set<String>()

        func add<T: KeepItem>(_ item: T, _ file: MarkdownFile, assets: [String: Data] = [:]) {
            let folder = T.kind.folder
            var name = "\(slug(item.title))-\(item.id.uuidString.prefix(8).lowercased()).md"
            if !usedNames.insert("\(folder)/\(name)").inserted { name = "\(item.id.uuidString.lowercased()).md" }
            folders[folder, default: [:]][name] = regular(Data(file.encoded().utf8), name)
            for (assetName, data) in assets {
                folders["\(folder)/assets", default: [:]][assetName] = regular(data, assetName)
            }
            items.append(.init(id: item.id, kind: T.kind, title: item.title, createdAt: item.createdAt,
                               updatedAt: item.updatedAt, categoryIds: item.categoryList.map(\.id), file: "\(folder)/\(name)"))
        }

        for word in try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.createdAt)])) {
            add(word, markdown(word))
        }
        for todo in try context.fetch(FetchDescriptor<TodoItem>(sortBy: [SortDescriptor(\.createdAt)])) {
            add(todo, markdown(todo))
        }
        for note in try context.fetch(FetchDescriptor<WikiNote>(sortBy: [SortDescriptor(\.createdAt)])) {
            var assets: [String: Data] = [:]
            for image in note.images ?? [] { if let data = image.data { assets[image.fileName] = data } }
            add(note, markdown(note), assets: assets)
        }
        for bookmark in try context.fetch(FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt)])) {
            var assets: [String: Data] = [:]
            if let data = bookmark.thumbnail { assets[thumbnailName(bookmark)] = data }
            add(bookmark, markdown(bookmark), assets: assets)
        }
        for meal in try context.fetch(FetchDescriptor<MealLog>(sortBy: [SortDescriptor(\.createdAt)])) {
            var assets: [String: Data] = [:]
            if let data = meal.photo { assets[photoName(meal)] = data }
            add(meal, markdown(meal), assets: assets)
        }
        for expense in try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.createdAt)])) {
            add(expense, markdown(expense))
        }

        let categories = try context.fetch(FetchDescriptor<ItemCategory>(sortBy: [SortDescriptor(\.name)]))
        let index = BackupIndex(exportedAt: now,
                                categories: categories.map { .init(id: $0.id, name: $0.name, createdAt: $0.createdAt) },
                                items: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        var root: [String: FileWrapper] = ["index.json": regular(try encoder.encode(index), "index.json")]
        // "wiki/assets"는 "wiki" 안으로 넣는다
        for (path, files) in folders.sorted(by: { $0.key < $1.key }) {
            let parts = path.split(separator: "/").map(String.init)
            let wrapper = FileWrapper(directoryWithFileWrappers: files)
            wrapper.preferredFilename = parts.last
            if parts.count == 1 {
                root[parts[0]] = merge(root[parts[0]], with: wrapper, name: parts[0])
            } else {
                let parent = root[parts[0]] ?? directory(parts[0])
                parent.addFileWrapper(wrapper)
                root[parts[0]] = parent
            }
        }
        return FileWrapper(directoryWithFileWrappers: root)
    }

    private static func common<T: KeepItem>(_ item: T) -> MarkdownFile {
        var file = MarkdownFile()
        file.set("id", item.id.uuidString)
        file.set("kind", T.kind.rawValue)
        file.set("title", item.title)
        file.set("categories", item.categoryList.map(\.name))
        file.set("created", item.createdAt.iso)
        file.set("updated", item.updatedAt.iso)
        return file
    }

    static func markdown(_ word: Word) -> MarkdownFile {
        var file = common(word)
        file.set("meaning", word.meaning)
        file.set("partOfSpeech", word.partOfSpeech)
        file.set("pronunciation", word.pronunciation)
        file.set("examples", word.examples.map { ["sentence": $0.sentence, "translation": $0.translation] })
        file.set("synonyms", word.synonyms)
        file.set("usageNote", word.usageNote)
        file.set("memo", word.memo)
        file.set("aiProvider", word.aiProvider)

        var body = ["# \(word.title)"]
        let meta = [word.partOfSpeech, word.pronunciation].filter { !$0.isEmpty }.joined(separator: " · ")
        if !meta.isEmpty { body.append("_\(meta)_") }
        if !word.meaning.isEmpty { body.append("## 뜻\n\n\(word.meaning)") }
        if !word.examples.isEmpty {
            body.append("## 예문\n\n" + word.examples.map { "- \($0.sentence)\n  - \($0.translation)" }.joined(separator: "\n"))
        }
        if !word.synonyms.isEmpty { body.append("## 비슷한 말\n\n\(word.synonyms.joined(separator: ", "))") }
        if !word.usageNote.isEmpty { body.append("## 이렇게 써요\n\n\(word.usageNote)") }
        if !word.memo.isEmpty { body.append("## 메모\n\n\(word.memo)") }
        file.body = body.joined(separator: "\n\n") + "\n"
        return file
    }

    static func markdown(_ todo: TodoItem) -> MarkdownFile {
        var file = common(todo)
        file.set("due", todo.dueDate?.iso)
        file.set("done", todo.isDone)
        file.set("completed", todo.completedAt?.iso)
        file.set("notes", todo.notes)
        var body = ["# \(todo.title)", "- [\(todo.isDone ? "x" : " ")] \(todo.title)"]
        if let due = todo.dueDate { body.append("날짜: \(due.formatted(date: .long, time: .omitted))") }
        if !todo.notes.isEmpty { body.append(todo.notes) }
        file.body = body.joined(separator: "\n\n") + "\n"
        return file
    }

    static func markdown(_ note: WikiNote) -> MarkdownFile {
        var file = common(note)
        file.set("images", (note.images ?? []).map(\.fileName))
        file.body = note.body
        return file
    }

    static func markdown(_ bookmark: Bookmark) -> MarkdownFile {
        var file = common(bookmark)
        file.set("url", bookmark.urlString)
        file.set("siteName", bookmark.siteName)
        file.set("note", bookmark.note)
        file.set("thumbnail", bookmark.thumbnail == nil ? nil : "assets/\(thumbnailName(bookmark))")
        var body = ["# \(bookmark.title)", "<\(bookmark.urlString)>"]
        if bookmark.thumbnail != nil { body.append("![](assets/\(thumbnailName(bookmark)))") }
        if !bookmark.note.isEmpty { body.append(bookmark.note) }
        file.body = body.joined(separator: "\n\n") + "\n"
        return file
    }

    static func markdown(_ meal: MealLog) -> MarkdownFile {
        var file = common(meal)
        file.set("day", meal.day.iso)
        file.set("mealTime", meal.mealTime.rawValue)
        file.set("photo", meal.photo == nil ? nil : "assets/\(photoName(meal))")
        var body = ["# \(meal.day.formatted(date: .long, time: .omitted)) \(meal.mealTime.label)"]
        if meal.photo != nil { body.append("![](assets/\(photoName(meal)))") }
        if !meal.title.isEmpty { body.append(meal.title) }
        file.body = body.joined(separator: "\n\n") + "\n"
        return file
    }

    static func markdown(_ expense: Expense) -> MarkdownFile {
        var file = common(expense)
        file.set("day", expense.day.iso)
        file.set("amount", expense.amount)
        var body = ["# \(expense.amount.won)", "날짜: \(expense.day.formatted(date: .long, time: .omitted))"]
        if !expense.title.isEmpty { body.append(expense.title) }
        file.body = body.joined(separator: "\n\n") + "\n"
        return file
    }

    // MARK: 가져오기

    static func restore(from root: FileWrapper, into context: ModelContext) throws -> RestoreSummary {
        guard let indexData = file(at: "index.json", in: root) else { throw BackupError.missingIndex }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let index = try decoder.decode(BackupIndex.self, from: indexData)

        // 카테고리: 같은 id → 같은 이름 → 새로 만들기
        let existing = try context.fetch(FetchDescriptor<ItemCategory>())
        var categoryByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for entry in index.categories where categoryByID[entry.id] == nil {
            if let same = existing.first(where: { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }) {
                categoryByID[entry.id] = same
            } else {
                let category = ItemCategory(name: entry.name)
                category.id = entry.id
                category.createdAt = entry.createdAt
                context.insert(category)
                categoryByID[entry.id] = category
            }
        }

        var summary = RestoreSummary()
        var words = try dictionary(Word.self, context)
        var todos = try dictionary(TodoItem.self, context)
        var notes = try dictionary(WikiNote.self, context)
        var bookmarks = try dictionary(Bookmark.self, context)
        var meals = try dictionary(MealLog.self, context)
        var expenses = try dictionary(Expense.self, context)

        for entry in index.items {
            guard let data = file(at: entry.file, in: root) else { summary.skipped += 1; continue }
            let md = MarkdownFile.decode(String(decoding: data, as: UTF8.self))
            let categories = entry.categoryIds.compactMap { categoryByID[$0] }
            let folder = (entry.file as NSString).deletingLastPathComponent

            switch entry.kind {
            case .word:
                upsert(entry, &words, context, &summary, make: { Word(title: entry.title) }) { word in
                    word.meaning = md.string("meaning")
                    word.partOfSpeech = md.string("partOfSpeech")
                    word.pronunciation = md.string("pronunciation")
                    word.examples = (md["examples"] as? [[String: String]] ?? []).map {
                        WordExample(sentence: $0["sentence"] ?? "", translation: $0["translation"] ?? "")
                    }
                    word.synonyms = md.strings("synonyms")
                    word.usageNote = md.string("usageNote")
                    word.memo = md.string("memo")
                    word.aiProvider = md.string("aiProvider")
                    word.aiStatus = word.meaning.isEmpty ? .none : .done
                    word.categories = categories
                }
            case .todo:
                upsert(entry, &todos, context, &summary, make: { TodoItem(title: entry.title) }) { todo in
                    todo.dueDate = md.date("due")
                    todo.isDone = md.bool("done")
                    todo.completedAt = md.date("completed")
                    todo.notes = md.string("notes")
                    todo.categories = categories
                }
            case .wiki:
                upsert(entry, &notes, context, &summary, make: { WikiNote(title: entry.title) }) { note in
                    note.body = md.body
                    let have = Set((note.images ?? []).map(\.fileName))
                    for name in md.strings("images") where !have.contains(name) {
                        guard let imageData = file(at: "\(folder)/assets/\(name)", in: root),
                              let id = UUID(uuidString: (name as NSString).deletingPathExtension) else { continue }
                        let image = WikiImage(id: id, data: imageData)
                        context.insert(image)
                        image.note = note
                    }
                    note.categories = categories
                }
            case .link:
                let url = URL(string: md.string("url")) ?? URL(string: "about:blank")!
                upsert(entry, &bookmarks, context, &summary, make: { Bookmark(url: url) }) { bookmark in
                    bookmark.urlString = md.string("url")
                    bookmark.siteName = md.string("siteName")
                    bookmark.note = md.string("note")
                    if let path = md["thumbnail"] as? String { bookmark.thumbnail = file(at: "\(folder)/\(path)", in: root) }
                    bookmark.metadataFetched = true
                    bookmark.categories = categories
                }
            case .meal:
                upsert(entry, &meals, context, &summary, make: { MealLog() }) { meal in
                    meal.day = md.date("day") ?? entry.createdAt
                    meal.mealTime = MealTime(rawValue: md.string("mealTime")) ?? .lunch
                    if let path = md["photo"] as? String { meal.photo = file(at: "\(folder)/\(path)", in: root) }
                    meal.categories = categories
                }
            case .expense:
                upsert(entry, &expenses, context, &summary, make: { Expense() }) { expense in
                    expense.day = md.date("day") ?? entry.createdAt
                    expense.amount = md.int("amount")
                    expense.categories = categories
                }
            }
        }
        try context.save()
        return summary
    }

    /// 같은 id가 있으면 백업 쪽이 더 최근일 때만 덮어씁니다.
    private static func upsert<T: KeepItem>(
        _ entry: BackupIndex.Item, _ existing: inout [UUID: T], _ context: ModelContext,
        _ summary: inout RestoreSummary, make: () -> T, apply: (T) -> Void
    ) {
        let item: T
        if let current = existing[entry.id] {
            guard entry.updatedAt > current.updatedAt.addingTimeInterval(1) else { summary.skipped += 1; return }
            item = current
            summary.updated += 1
        } else {
            item = make()
            item.id = entry.id
            context.insert(item)
            existing[entry.id] = item
            summary.created += 1
        }
        item.title = entry.title
        apply(item)
        item.createdAt = entry.createdAt
        item.updatedAt = entry.updatedAt
    }

    private static func dictionary<T: KeepItem>(_ type: T.Type, _ context: ModelContext) throws -> [UUID: T] {
        Dictionary(try context.fetch(FetchDescriptor<T>()).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: 파일 도우미

    static func file(at path: String, in root: FileWrapper) -> Data? {
        var node: FileWrapper? = root
        for part in path.split(separator: "/") {
            node = node?.fileWrappers?[String(part)]
        }
        return node?.regularFileContents
    }

    static func slug(_ title: String) -> String {
        let mapped = title.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        let collapsed = mapped.split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "untitled" : String(collapsed.prefix(40))
    }

    private static func thumbnailName(_ bookmark: Bookmark) -> String { "\(bookmark.id.uuidString.lowercased()).jpg" }
    private static func photoName(_ meal: MealLog) -> String { "\(meal.id.uuidString.lowercased()).jpg" }

    private static func regular(_ data: Data, _ name: String) -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = name
        return wrapper
    }

    private static func directory(_ name: String) -> FileWrapper {
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        wrapper.preferredFilename = name
        return wrapper
    }

    private static func merge(_ existing: FileWrapper?, with new: FileWrapper, name: String) -> FileWrapper {
        guard let existing else { return new }
        for child in (new.fileWrappers ?? [:]).values { existing.addFileWrapper(child) }
        return existing
    }
}

/// .fileExporter에 넘기는 폴더 문서
struct BackupDocument: FileDocument, @unchecked Sendable {
    nonisolated static var readableContentTypes: [UTType] { [.folder] }
    let wrapper: FileWrapper

    init(wrapper: FileWrapper) { self.wrapper = wrapper }

    nonisolated init(configuration: ReadConfiguration) throws {
        wrapper = configuration.file
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { wrapper }
}
