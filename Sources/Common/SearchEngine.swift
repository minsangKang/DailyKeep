import Foundation

/// 모든 탭이 같이 쓰는 검색 규칙. 공백으로 나눈 단어가 모두 들어 있어야 맞는 것으로 봅니다.
/// 카테고리 이름도 검색 대상이고, 카테고리 필터는 고른 카테고리를 모두 가진 항목만 남깁니다.
enum SearchEngine {
    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
            .filter { !$0.isEmpty }
    }

    static func matches(_ text: String, query: String) -> Bool {
        terms(in: query).allSatisfy { text.localizedStandardContains($0) }
    }

    static func filter<T: KeepItem>(_ items: [T], query: String, categoryIDs: Set<UUID> = []) -> [T] {
        items.filter { item in
            let hasCategories = categoryIDs.isEmpty
                || Set((item.categories ?? []).map(\.id)).isSuperset(of: categoryIDs)
            return hasCategories && matches(item.searchText, query: query)
        }
    }
}
