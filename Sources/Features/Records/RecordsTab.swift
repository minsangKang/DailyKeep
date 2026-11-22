import SwiftUI

/// 기록 탭: 식사와 지출을 위쪽 세그먼트로 오가며 씁니다. 마지막으로 본 쪽을 기억합니다.
struct RecordsTab: View {
    enum Mode: String, CaseIterable { case meal = "식사", expense = "지출" }

    @AppStorage("recordMode") private var mode = Mode.meal

    var body: some View {
        Group {
            switch mode {
            case .meal: MealsView()
            case .expense: ExpensesView()
            }
        }
        .navigationTitle("기록")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("기록", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .settingsToolbar()
    }
}

extension Date {
    /// 기록 목록의 날짜 머리글: 오늘 / 어제 / 11월 20일 (목)
    var dayHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "오늘" }
        if calendar.isDateInYesterday(self) { return "어제" }
        if calendar.isDate(self, equalTo: .now, toGranularity: .year) { return dayWithWeekday }
        return formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }
}

extension Array {
    /// 같은 날끼리 묶습니다. 입력 순서(최근 날짜 먼저)를 그대로 유지합니다.
    func groupedByDay(_ day: (Element) -> Date) -> [(day: Date, items: [Element])] {
        var groups: [(day: Date, items: [Element])] = []
        for element in self {
            let key = Calendar.current.startOfDay(for: day(element))
            if let last = groups.indices.last, groups[last].day == key {
                groups[last].items.append(element)
            } else {
                groups.append((key, [element]))
            }
        }
        return groups
    }
}
