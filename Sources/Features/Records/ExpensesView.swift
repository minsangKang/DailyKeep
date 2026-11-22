import SwiftData
import SwiftUI

/// 지출 기록 목록. 위에 이번 달 합계, 날짜마다 그날 합계를 보여줍니다.
struct ExpensesView: View {
    @Query(sort: [SortDescriptor(\Expense.day, order: .reverse), SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var expenses: [Expense]
    @Environment(\.modelContext) private var context
    @State private var categoryID: UUID?
    @State private var adding = false
    @State private var editing: Expense?

    private var filtered: [Expense] {
        SearchEngine.filter(expenses, query: "", categoryIDs: categoryID.map { [$0] } ?? [])
    }

    private var monthTotal: Int {
        filtered.filter { Calendar.current.isDate($0.day, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            CategoryFilterBar(categories: expenses.usedCategories, selection: $categoryID)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            if !expenses.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("이번 달").foregroundStyle(.secondary)
                    Spacer()
                    Text(monthTotal.won).font(.title2.bold()).monospacedDigit()
                }
                .listRowSeparator(.hidden)
            }
            ForEach(filtered.groupedByDay(\.day), id: \.day) { group in
                Section {
                    ForEach(group.items) { expense in
                        Button { editing = expense } label: { ExpenseRow(expense: expense) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("삭제", systemImage: "trash", role: .destructive) { context.delete(expense) }
                            }
                            .contextMenu {
                                Button("편집", systemImage: "pencil") { editing = expense }
                                Button("삭제", systemImage: "trash", role: .destructive) { context.delete(expense) }
                            }
                    }
                } header: {
                    HStack {
                        Text(group.day.dayHeader)
                        Spacer()
                        Text(group.items.reduce(0) { $0 + $1.amount }.won).monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.plain)
        .emptyState {
            if expenses.isEmpty {
                ContentUnavailableView("쓴 돈을 적어보세요", systemImage: "wonsign.circle",
                                       description: Text("금액과 카테고리, 어디에 썼는지만 간단히 남겨요."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Button("지출 기록", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) {
            ExpenseEditor(expense: nil, category: expenses.usedCategories.first { $0.id == categoryID })
        }
        .sheet(item: $editing) { ExpenseEditor(expense: $0) }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    var showsDate = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title.nonEmpty ?? "메모 없음")
                    .foregroundStyle(expense.title.nonEmpty == nil ? .secondary : .primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if showsDate { Text(expense.day.dayHeader).font(.caption).foregroundStyle(.secondary) }
                    CategoryTags(categories: expense.categoryList)
                }
            }
            Spacer()
            Text(expense.amount.won).font(.body.weight(.semibold)).monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

/// 새 지출 또는 기존 지출 편집. 금액 입력칸에 바로 커서가 갑니다.
struct ExpenseEditor: View {
    private let expense: Expense?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var day: Date
    @State private var categories: [ItemCategory]
    @State private var memo: String
    @FocusState private var amountFocused: Bool

    init(expense: Expense?, category: ItemCategory? = nil) {
        self.expense = expense
        _amountText = State(initialValue: expense.map { $0.amount.formatted() } ?? "")
        _day = State(initialValue: expense?.day ?? .now)
        _categories = State(initialValue: expense?.categoryList ?? (category.map { [$0] } ?? []))
        _memo = State(initialValue: expense?.title ?? "")
    }

    private var amount: Int { Int(amountText.filter(\.isNumber)) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("금액") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0", text: $amountText)
                            .font(.largeTitle.bold())
                            .monospacedDigit()
                            .focused($amountFocused)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("원").font(.title2).foregroundStyle(.secondary)
                    }
                }
                Section {
                    DatePicker("날짜", selection: $day, displayedComponents: .date)
                    CategoryDraftField(categories: $categories)
                    TextField("메모 · 어디에 썼나요?", text: $memo, axis: .vertical)
                }
                if let expense {
                    Section {
                        Button("기록 삭제", role: .destructive) {
                            context.delete(expense)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(expense == nil ? "지출 기록" : "지출 편집")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(amount <= 0)
                }
            }
            // 입력하는 대로 세 자리마다 쉼표를 넣습니다(최대 12자리)
            .onChange(of: amountText) { _, text in
                let digits = String(text.filter(\.isNumber).prefix(12))
                let formatted = Int(digits).map { $0.formatted() } ?? ""
                if formatted != text { amountText = formatted }
            }
            .onAppear { if expense == nil { amountFocused = true } }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
    }

    private func save() {
        let target = expense ?? {
            let created = Expense()
            context.insert(created)
            return created
        }()
        target.amount = amount
        target.day = Calendar.current.startOfDay(for: day)
        target.categories = categories
        target.title = memo.nonEmpty ?? ""
        target.touch()
        dismiss()
    }
}
