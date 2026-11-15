import SwiftData
import SwiftUI

struct MonthCalendarView: View {
    @Binding var month: Date
    @Binding var selectedDay: Date

    @Query private var todos: [TodoItem]
    @Environment(CalendarEventStore.self) private var eventStore

    private let calendar = Calendar.current
    /// 한 주 줄의 최대 높이. 칸이 넉넉해도 이보다 커지지 않고 위로 모입니다.
    private let maxRowHeight: CGFloat = 56

    var body: some View {
        let days = monthDays
        let weeks = days.count / 7
        let events = eventStore.events(in: visibleInterval(days))
        VStack(spacing: 8) {
            header
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            // 남은 높이를 주 수로 나눠 칸 크기를 정합니다. 세로로 나뉜 작은 칸에서도 넘치지 않습니다.
            GeometryReader { proxy in
                let rowHeight = min(maxRowHeight, proxy.size.height / CGFloat(max(weeks, 1)))
                VStack(spacing: 0) {
                    ForEach(0..<weeks, id: \.self) { week in
                        HStack(spacing: 0) {
                            ForEach(days[(week * 7)..<(week * 7 + 7)], id: \.self) { day in
                                DayCell(
                                    day: day,
                                    rowHeight: rowHeight,
                                    inMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                                    isToday: calendar.isDateInToday(day),
                                    hasTodo: todos.contains { !$0.isDone && $0.dueDate.map { calendar.isDate($0, inSameDayAs: day) } == true },
                                    eventColors: Array(events.filter { $0.occurs(on: day) }.map(\.color).prefix(3))
                                )
                                .onTapGesture { selectedDay = day }
                            }
                        }
                        .frame(height: rowHeight)
                    }
                }
            }
            .frame(minHeight: CGFloat(weeks) * 20, maxHeight: CGFloat(weeks) * maxRowHeight)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .clipped()
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if value.translation.width < -50 { shift(1) } else if value.translation.width > 50 { shift(-1) }
        })
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(month.formatted(.dateTime.year().month(.wide)))
                    .font(.title2.bold())
                legend
            }
            Spacer()
            Button("오늘") {
                selectedDay = calendar.startOfDay(for: .now)
                month = selectedDay
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            Button("이전 달", systemImage: "chevron.left") { shift(-1) }
                .labelStyle(.iconOnly)
            Button("다음 달", systemImage: "chevron.right") { shift(1) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label { Text("내 할 일") } icon: { Circle().fill(Color.primary).frame(width: 6, height: 6) }
            if eventStore.isAuthorized && eventStore.isEnabled {
                Label { Text("캘린더 일정") } icon: { Circle().strokeBorder(Color.secondary, lineWidth: 1.5).frame(width: 7, height: 7) }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 달력에 보이는 날들. 그 달에 필요한 주(4~6주)만큼만 만듭니다.
    private var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let offset = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let weeks = Int((Double(offset + dayCount) / 7).rounded(.up))
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: interval.start) else { return [] }
        return (0..<(weeks * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func visibleInterval(_ days: [Date]) -> DateInterval {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return DateInterval() }
        return DateInterval(start: first, end: end)
    }

    private func shift(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) { month = next }
    }
}

private struct DayCell: View {
    let day: Date
    let rowHeight: CGFloat
    let inMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let hasTodo: Bool
    let eventColors: [Color]

    /// 줄이 낮으면 점을 숨기고 숫자 원만 남깁니다.
    private var showsDots: Bool { rowHeight >= 34 }
    private var diameter: CGFloat { max(16, min(34, rowHeight - (showsDots ? 12 : 2))) }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.system(size: diameter * 0.47, weight: isToday ? .bold : .regular))
                .frame(width: diameter, height: diameter)
                .foregroundStyle(isSelected ? Color.platformBackground : (inMonth ? Color.primary : Color.secondary.opacity(0.5)))
                .background {
                    if isSelected { Circle().fill(Color.primary) }
                    else if isToday { Circle().strokeBorder(Color.primary, lineWidth: 1) }
                }
            if showsDots {
                HStack(spacing: 3) {
                    if hasTodo { Circle().fill(Color.primary).frame(width: 5, height: 5) }
                    ForEach(eventColors.indices, id: \.self) { i in
                        Circle().fill(eventColors[i]).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            // 점을 숨겼을 때는 할 일이 있는 날만 아래 작은 막대로 표시
            if !showsDots && (hasTodo || !eventColors.isEmpty) {
                Capsule().fill(hasTodo ? Color.primary : (eventColors.first ?? .secondary))
                    .frame(width: 10, height: 2)
            }
        }
        .contentShape(.rect)
    }
}
