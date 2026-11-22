import Foundation
import SwiftData

enum ItemKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case word, todo, wiki, link, meal, expense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .word: "단어"
        case .todo: "할 일"
        case .wiki: "위키"
        case .link: "링크"
        case .meal: "식사"
        case .expense: "지출"
        }
    }

    var systemImage: String {
        switch self {
        case .word: "character.book.closed"
        case .todo: "checklist"
        case .wiki: "book.pages"
        case .link: "link"
        case .meal: "fork.knife"
        case .expense: "wonsign.circle"
        }
    }

    /// 백업 폴더 이름
    var folder: String {
        switch self {
        case .word: "words"
        case .todo: "todos"
        case .wiki: "wiki"
        case .link: "links"
        case .meal: "meals"
        case .expense: "expenses"
        }
    }
}

/// 모든 종류가 공유하는 메타정보: 타이틀, 날짜, 카테고리(다대다).
nonisolated protocol KeepItem: PersistentModel {
    static var kind: ItemKind { get }
    var id: UUID { get set }
    var title: String { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var categories: [ItemCategory]? { get set }
    /// 검색에 쓰는 본문 텍스트(타이틀·카테고리 이름 제외)
    var bodyText: String { get }
}

nonisolated extension KeepItem {
    var categoryList: [ItemCategory] {
        (categories ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var searchText: String {
        ([title, bodyText] + categoryList.map(\.name)).joined(separator: "\n")
    }

    func touch() { updatedAt = .now }

    func setCategories(_ new: [ItemCategory]) {
        categories = new
        touch()
    }
}
