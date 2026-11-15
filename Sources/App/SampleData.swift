#if DEBUG
import Foundation
import SwiftData

/// 디버그 빌드에서 `-seedSampleData` 인자로 실행하면 화면 확인용 샘플을 넣습니다(비어 있을 때만).
enum SampleData {
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData"),
              ((try? context.fetchCount(FetchDescriptor<Word>())) ?? 0) == 0 else { return }

        let english = ItemCategory(name: "영어")
        let dev = ItemCategory(name: "개발")
        let shopping = ItemCategory(name: "쇼핑")
        [english, dev, shopping].forEach(context.insert)

        let word = Word(title: "serendipity")
        word.meaning = "뜻밖의 행운, 우연히 좋은 것을 발견하는 일"
        word.partOfSpeech = "noun"
        word.pronunciation = "/ˌser.ənˈdɪp.ə.ti/"
        word.examples = [
            WordExample(sentence: "Finding this café was pure serendipity.", translation: "이 카페를 찾은 건 순전히 뜻밖의 행운이었다."),
            WordExample(sentence: "Many discoveries happen by serendipity.", translation: "많은 발견은 우연히 일어난다."),
        ]
        word.synonyms = ["luck", "chance", "fortune"]
        word.usageNote = "계획하지 않았는데 좋은 일이 생겼을 때 씁니다. 긍정적인 뉘앙스입니다."
        word.aiStatus = .done
        word.aiProvider = "샘플"
        word.categories = [english]
        context.insert(word)

        let korean = Word(title: "미장센")
        korean.meaning = "화면 안의 배치와 연출 전체"
        korean.partOfSpeech = "명사"
        korean.aiStatus = .done
        context.insert(korean)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todo1 = TodoItem(title: "장보기", dueDate: today)
        todo1.categories = [shopping]
        let todo2 = TodoItem(title: "SwiftData 마이그레이션 읽기", dueDate: calendar.date(byAdding: .day, value: 2, to: today))
        todo2.categories = [dev]
        let todo3 = TodoItem(title: "책장 정리")
        [todo1, todo2, todo3].forEach(context.insert)

        let note = WikiNote(title: "ArrangementView 메모", body: """
        # 언제 쓰나
        탐색 컨테이너와 콘텐츠 컨테이너 **사이**에 둡니다.

        - split: 나란히
        - overlay: 겹치기
        - [x] NavigationStack 안에 넣기

        > 스크롤 컨테이너 안에는 넣지 않습니다.
        """)
        note.categories = [dev]
        context.insert(note)

        let link = Bookmark(url: URL(string: "https://www.apple.com/iphone/")!)
        link.categories = [shopping]
        context.insert(link)
        context.insert(Bookmark(url: URL(string: "https://developer.apple.com/documentation/swiftui")!))
    }
}
#endif
