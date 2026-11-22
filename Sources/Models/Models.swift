import Foundation
import SwiftData

// CloudKit 동기화 제약: 모든 속성은 기본값 또는 옵셔널, unique 제약 없음, 관계는 옵셔널.

@Model
final class ItemCategory {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    @Relationship(inverse: \Word.categories) var words: [Word]? = []
    @Relationship(inverse: \TodoItem.categories) var todos: [TodoItem]? = []
    @Relationship(inverse: \WikiNote.categories) var notes: [WikiNote]? = []
    @Relationship(inverse: \Bookmark.categories) var bookmarks: [Bookmark]? = []
    @Relationship(inverse: \MealLog.categories) var meals: [MealLog]? = []
    @Relationship(inverse: \Expense.categories) var expenses: [Expense]? = []

    init(name: String) {
        self.name = name
    }

    var itemCount: Int {
        (words?.count ?? 0) + (todos?.count ?? 0) + (notes?.count ?? 0) + (bookmarks?.count ?? 0)
            + (meals?.count ?? 0) + (expenses?.count ?? 0)
    }
}

struct WordExample: Codable, Hashable {
    var sentence: String
    var translation: String
}

enum AIStatus: String, Codable {
    case none, pending, done, failed
}

@Model
final class Word: KeepItem {
    static let kind = ItemKind.word

    var id: UUID = UUID()
    /// 단어 자체
    var title: String = ""
    var meaning: String = ""
    var partOfSpeech: String = ""
    var pronunciation: String = ""
    var examples: [WordExample] = []
    var synonyms: [String] = []
    var usageNote: String = ""
    var memo: String = ""
    var aiStatusRaw: String = AIStatus.none.rawValue
    var aiProvider: String = ""
    var aiError: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(title: String) {
        self.title = title
    }

    var aiStatus: AIStatus {
        get { AIStatus(rawValue: aiStatusRaw) ?? .none }
        set { aiStatusRaw = newValue.rawValue }
    }

    var bodyText: String {
        ([meaning, partOfSpeech, usageNote, memo] + synonyms + examples.map(\.sentence)).joined(separator: "\n")
    }
}

@Model
final class TodoItem: KeepItem {
    static let kind = ItemKind.todo

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var isDone: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(title: String, dueDate: Date? = nil) {
        self.title = title
        self.dueDate = dueDate
    }

    var bodyText: String { notes }

    func toggle() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
        touch()
    }
}

@Model
final class WikiNote: KeepItem {
    static let kind = ItemKind.wiki

    var id: UUID = UUID()
    var title: String = ""
    /// 마크다운. 이미지는 `![](assets/<uuid>.jpg)`로 참조합니다.
    var body: String = ""
    @Relationship(deleteRule: .cascade, inverse: \WikiImage.note) var images: [WikiImage]? = []
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(title: String, body: String = "") {
        self.title = title
        self.body = body
    }

    var bodyText: String { body }

    func image(for path: String) -> WikiImage? {
        images?.first { $0.assetPath == path }
    }
}

@Model
final class WikiImage {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    var createdAt: Date = Date.now
    var note: WikiNote?

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }

    var fileName: String { "\(id.uuidString.lowercased()).jpg" }
    var assetPath: String { "assets/\(fileName)" }
}

@Model
final class Bookmark: KeepItem {
    static let kind = ItemKind.link

    var id: UUID = UUID()
    var title: String = ""
    var urlString: String = ""
    var siteName: String = ""
    var note: String = ""
    @Attribute(.externalStorage) var thumbnail: Data?
    var metadataFetched: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(url: URL) {
        self.urlString = url.absoluteString
        self.title = url.host() ?? url.absoluteString
    }

    var url: URL? { URL(string: urlString) }
    var host: String { url?.host()?.replacingOccurrences(of: "www.", with: "") ?? "" }
    var bodyText: String { [urlString, siteName, note].joined(separator: "\n") }
}

/// 식사 시간대. 목록에서 하루 안의 순서도 이 순서를 따릅니다.
nonisolated enum MealTime: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, snack, dinner, lateNight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: "아침"
        case .lunch: "점심"
        case .snack: "간식"
        case .dinner: "저녁"
        case .lateNight: "야식"
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// 지금 시각에 맞는 기본 시간대
    static func guess(at date: Date = .now) -> MealTime {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<15: .lunch
        case 15..<17: .snack
        case 17..<21: .dinner
        default: .lateNight
        }
    }
}

@Model
final class MealLog: KeepItem {
    static let kind = ItemKind.meal

    var id: UUID = UUID()
    /// 간단 메모. 목록·검색·백업에서 제목으로 씁니다.
    var title: String = ""
    /// 먹은 날(그날 0시)
    var day: Date = Date.now
    var mealTimeRaw: String = MealTime.lunch.rawValue
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(title: String = "", day: Date = .now, mealTime: MealTime = .guess()) {
        self.title = title
        self.day = Calendar.current.startOfDay(for: day)
        self.mealTimeRaw = mealTime.rawValue
    }

    var mealTime: MealTime {
        get { MealTime(rawValue: mealTimeRaw) ?? .lunch }
        set { mealTimeRaw = newValue.rawValue }
    }

    /// 시간대 이름으로도 찾을 수 있게 합니다("점심" 검색)
    var bodyText: String { mealTime.label }
}

@Model
final class Expense: KeepItem {
    static let kind = ItemKind.expense

    var id: UUID = UUID()
    /// 간단 메모(어디에 썼는지). 목록·검색·백업에서 제목으로 씁니다.
    var title: String = ""
    /// 원 단위 금액
    var amount: Int = 0
    /// 쓴 날(그날 0시)
    var day: Date = Date.now
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var categories: [ItemCategory]? = []

    init(title: String = "", amount: Int = 0, day: Date = .now) {
        self.title = title
        self.amount = amount
        self.day = Calendar.current.startOfDay(for: day)
    }

    var bodyText: String { amount.won }
}

nonisolated extension Int {
    /// 12,000원
    var won: String { "\(formatted())원" }
}
