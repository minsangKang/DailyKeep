import SwiftData
import SwiftUI

/// 기존 카테고리 다중 선택 + 같은 입력칸에서 새로 만들기. 모든 종류가 공유합니다.
struct CategoryPicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ItemCategory.name) private var all: [ItemCategory]

    @State private var selected: Set<UUID>
    @State private var text = ""
    @FocusState private var focused: Bool
    let onDone: ([ItemCategory]) -> Void

    init(selected: [ItemCategory], onDone: @escaping ([ItemCategory]) -> Void) {
        _selected = State(initialValue: Set(selected.map(\.id)))
        self.onDone = onDone
    }

    private var filtered: [ItemCategory] {
        text.nonEmpty == nil ? all : all.filter { $0.name.localizedStandardContains(text) }
    }

    private var canCreate: Bool {
        guard let name = text.nonEmpty else { return false }
        return !all.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "number").foregroundStyle(.secondary)
                        TextField("찾거나 새로 만들기", text: $text)
                            .focused($focused)
                            .noAutocapitalization()
                            .onSubmit(createOrPick)
                    }
                    if canCreate {
                        Button(action: createOrPick) {
                            Label("‘\(text.nonEmpty ?? "")’ 만들기", systemImage: "plus")
                        }
                    }
                }
                Section {
                    ForEach(filtered) { category in
                        Button {
                            toggle(category.id)
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                if selected.contains(category.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    if all.isEmpty { Text("위 입력칸에 이름을 적고 Return을 누르면 카테고리가 만들어집니다.") }
                }
            }
            .navigationTitle("카테고리")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onDone(all.filter { selected.contains($0.id) })
                        dismiss()
                    }
                }
            }
        }
        .onAppear { if all.isEmpty { focused = true } }
        #if os(macOS)
        .frame(minWidth: 320, minHeight: 380)
        #endif
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func createOrPick() {
        guard let name = text.nonEmpty, let category = context.category(named: name) else { return }
        selected.insert(category.id)
        text = ""
    }
}

/// 상세 화면의 "카테고리" 행. 누르면 CategoryPicker가 열립니다.
struct CategoriesField<Item: KeepItem>: View {
    let item: Item
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "number").foregroundStyle(.secondary)
                if item.categoryList.isEmpty {
                    Text("카테고리 추가").foregroundStyle(.secondary)
                } else {
                    Text(item.categoryList.map(\.name).joined(separator: ", "))
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $picking) {
            CategoryPicker(selected: item.categoryList) { item.setCategories($0) }
        }
    }
}

/// 목록 상단의 카테고리 필터. 해당 종류에서 쓰인 카테고리만 보여줍니다.
struct CategoryFilterBar: View {
    let categories: [ItemCategory]
    @Binding var selection: UUID?

    var body: some View {
        if !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { selection = nil } label: { Chip(title: "전체", isSelected: selection == nil) }
                    ForEach(categories) { category in
                        Button {
                            selection = selection == category.id ? nil : category.id
                        } label: {
                            Chip(title: category.name, isSelected: selection == category.id)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }
}

extension Array where Element: KeepItem {
    /// 이 항목들에 쓰인 카테고리(중복 없이, 이름순)
    var usedCategories: [ItemCategory] {
        var seen = Set<UUID>()
        return flatMap { $0.categories ?? [] }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// 저장 버튼을 눌러야 반영되는 편집 화면(식사·지출)의 "카테고리" 행.
/// 고른 카테고리를 바인딩으로만 들고 있다가 저장할 때 항목에 넣습니다.
struct CategoryDraftField: View {
    @Binding var categories: [ItemCategory]
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "number").foregroundStyle(.secondary)
                if categories.isEmpty {
                    Text("카테고리 추가").foregroundStyle(.secondary)
                } else {
                    Text(categories.map(\.name).joined(separator: ", "))
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $picking) {
            CategoryPicker(selected: categories) { categories = $0 }
        }
    }
}
