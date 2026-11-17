import SwiftData
import SwiftUI

/// 쭉 쌓이는 전체 할 일. 지난 일 · 오늘 · 예정 · 날짜 없음 · 완료 순서로 묶습니다.
struct TodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var categoryID: UUID?
    @AppStorage("showDoneTodos") private var showDone = false

    private var groups: [(String, [TodoItem])] {
        let filtered = SearchEngine.filter(todos, query: query, categoryIDs: categoryID.map { [$0] } ?? [])
        let today = Calendar.current.startOfDay(for: .now)
        let open = filtered.filter { !$0.isDone }
        func dated(_ test: (Date) -> Bool) -> [TodoItem] {
            open.filter { $0.dueDate.map(test) == true }.sorted { ($0.dueDate ?? .now) < ($1.dueDate ?? .now) }
        }
        var result: [(String, [TodoItem])] = [
            ("지난 일", dated { $0 < today }),
            ("오늘", dated { Calendar.current.isDateInToday($0) }),
            ("예정", dated { $0 >= today && !Calendar.current.isDateInToday($0) }),
            ("날짜 없음", open.filter { $0.dueDate == nil }),
        ]
        if showDone {
            result.append(("완료", filtered.filter(\.isDone).sorted { ($0.completedAt ?? .now) > ($1.completedAt ?? .now) }))
        }
        return result.filter { !$0.1.isEmpty }
    }

    private var currentCategory: ItemCategory? { todos.usedCategories.first { $0.id == categoryID } }

    var body: some View {
        List {
            CategoryFilterBar(categories: todos.usedCategories, selection: $categoryID)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            ForEach(groups, id: \.0) { title, items in
                Section(title) {
                    ForEach(items) { todo in
                        NavigationLink(value: todo) { TodoRow(todo: todo) }
                    }
                    .onDelete { $0.map { items[$0] }.forEach(context.delete) }
                }
            }
        }
        .listStyle(.plain)
        .emptyState {
            if todos.isEmpty {
                ContentUnavailableView("할 일이 없어요", systemImage: "checklist", description: Text("아래 입력칸에 적으면 바로 쌓입니다."))
            }
        }
        .searchable(text: $query, prompt: "할 일, 메모, 카테고리")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddBar(placeholder: currentCategory.map { "#\($0.name)에 할 일 추가" } ?? "할 일 추가") { title in
                let todo = TodoItem(title: title)
                if let currentCategory { todo.categories = [currentCategory] }
                context.insert(todo)
            }
        }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Toggle("완료 보기", systemImage: "checkmark.circle", isOn: $showDone)
            }
        }
    }
}

struct TodoDetailView: View {
    @Bindable var todo: TodoItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var hasDate: Binding<Bool> {
        Binding {
            todo.dueDate != nil
        } set: { on in
            todo.dueDate = on ? Calendar.current.startOfDay(for: .now) : nil
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button { todo.toggle() } label: {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle").font(.title2)
                    }
                    .buttonStyle(.plain)
                    TextField("할 일", text: $todo.title, axis: .vertical).font(.title3)
                }
                CategoriesField(item: todo)
            }
            Section {
                Toggle("날짜", isOn: hasDate)
                    .monochromeToggle()
                if let due = todo.dueDate {
                    DatePicker("날짜", selection: Binding { due } set: { todo.dueDate = $0 }, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            Section("메모") {
                TextField("메모", text: $todo.notes, axis: .vertical)
            }
            Section { MetaFooter(item: todo) }
        }
        .navigationTitle("할 일")
        .inlineTitle()
        .onChange(of: todo.title) { todo.touch() }
        .onChange(of: todo.notes) { todo.touch() }
        .onChange(of: todo.dueDate) { todo.touch() }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Button("삭제", systemImage: "trash", role: .destructive) {
                    context.delete(todo)
                    dismiss()
                }
            }
        }
    }
}
