import SwiftData
import SwiftUI

struct TodoTab: View {
    enum Mode: String, CaseIterable { case calendar = "캘린더", all = "전체" }

    @AppStorage("todoMode") private var mode = Mode.calendar
    @Environment(CalendarEventStore.self) private var events

    var body: some View {
        Group {
            switch mode {
            case .calendar: TodoCalendarView()
            case .all: TodoListView()
            }
        }
        .navigationTitle("할 일")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("보기", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .navigationDestination(for: TodoItem.self) { TodoDetailView(todo: $0) }
        .settingsToolbar()
        .task { await events.requestAccessIfNeeded() }
    }
}

/// ArrangementView(split) — 주 뷰는 월 달력, 보조 뷰는 고른 날의 일정 목록.
struct TodoCalendarView: View {
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var month = Calendar.current.startOfDay(for: .now)

    var body: some View {
        Arranged(.split) {
            MonthCalendarView(month: $month, selectedDay: $selectedDay)
        } secondary: {
            DayAgendaView(day: selectedDay)
        }
    }
}

struct TodoRow: View {
    let todo: TodoItem
    var showsDate = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button {
                withAnimation(.snappy) { todo.toggle() }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                HStack(spacing: 8) {
                    if showsDate, let due = todo.dueDate {
                        Text(due.dayWithWeekday)
                            .foregroundStyle(!todo.isDone && due < Calendar.current.startOfDay(for: .now) ? .primary : .secondary)
                    }
                    CategoryTags(categories: todo.categoryList)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 기본 캘린더 일정 행. 캘린더 색 막대로 앱 할 일과 구분하고, 체크할 수 없습니다.
struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            Capsule().fill(event.color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                Text("\(event.timeText) · \(event.calendarName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "calendar").font(.caption).foregroundStyle(event.color)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("캘린더 일정 \(event.title), \(event.timeText)")
    }
}
