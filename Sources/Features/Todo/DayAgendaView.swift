import SwiftData
import SwiftUI

/// 고른 날의 기본 캘린더 일정(읽기 전용) + 내 할 일.
struct DayAgendaView: View {
    let day: Date

    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Environment(\.modelContext) private var context
    @Environment(CalendarEventStore.self) private var eventStore

    private var dayTodos: [TodoItem] {
        todos.filter { $0.dueDate.map { Calendar.current.isDate($0, inSameDayAs: day) } == true }
            .sorted { !$0.isDone && $1.isDone }
    }

    var body: some View {
        let events = eventStore.events(in: Calendar.current.dateInterval(of: .day, for: day) ?? DateInterval())
        List {
            Section {
                if !events.isEmpty {
                    ForEach(events) { CalendarEventRow(event: $0) }
                }
                ForEach(dayTodos) { todo in
                    NavigationLink(value: todo) { TodoRow(todo: todo, showsDate: false) }
                }
                .onDelete { $0.map { dayTodos[$0] }.forEach(context.delete) }
                if events.isEmpty && dayTodos.isEmpty {
                    Text("비어 있는 날이에요").foregroundStyle(.secondary)
                }
            } header: {
                Text(day.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddBar(placeholder: "\(day.shortDay) 할 일 추가") { title in
                context.insert(TodoItem(title: title, dueDate: day))
            }
        }
    }
}
