import EventKit
import SwiftUI

/// 기본 캘린더 일정을 읽기 전용으로 가져옵니다. 권한이 없으면 빈 목록입니다.
@Observable
final class CalendarEventStore {
    static let showKey = "showSystemEvents"

    private let store = EKEventStore()
    private(set) var isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    private(set) var revision = 0
    private var observer: (any NSObjectProtocol)?

    /// 저장 속성이어야 Observation이 변화를 알아채 토글·달력이 바로 갱신됩니다.
    var isEnabled: Bool = UserDefaults.standard.object(forKey: CalendarEventStore.showKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.showKey)
            revision += 1
        }
    }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.revision += 1 }
        }
    }

    var statusDescription: String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: "허용됨"
        case .denied, .restricted: "거부됨 — 시스템 설정에서 허용할 수 있습니다"
        case .writeOnly: "쓰기 전용 — 전체 접근이 필요합니다"
        default: "아직 묻지 않음"
        }
    }

    func requestAccessIfNeeded() async {
        guard isEnabled, EKEventStore.authorizationStatus(for: .event) == .notDetermined else { return }
        isAuthorized = (try? await store.requestFullAccessToEvents()) ?? false
        revision += 1
    }

    /// 기간 안의 일정. revision을 읽어 변경 시 화면이 다시 그려지게 합니다.
    func events(in interval: DateInterval) -> [CalendarEvent] {
        _ = revision
        guard isEnabled, isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).map(CalendarEvent.init)
    }
}

/// 화면에서 쓰는 일정 값 타입
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let calendarName: String

    init(_ event: EKEvent) {
        id = (event.eventIdentifier ?? UUID().uuidString) + "\(event.startDate.timeIntervalSince1970)"
        title = event.title ?? "(제목 없음)"
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        color = Color(cgColor: event.calendar.cgColor)
        calendarName = event.calendar.title
    }

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return start < dayEnd && end > dayStart || calendar.isDate(start, inSameDayAs: day)
    }

    var timeText: String {
        isAllDay ? "하루 종일" : start.formatted(date: .omitted, time: .shortened)
    }
}
