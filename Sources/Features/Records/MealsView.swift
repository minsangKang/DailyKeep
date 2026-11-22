import PhotosUI
import SwiftData
import SwiftUI

/// 식사 기록 목록. 날짜별로 묶고, 하루 안에서는 아침 → 야식 순서로 보여줍니다.
struct MealsView: View {
    @Query(sort: [SortDescriptor(\MealLog.day, order: .reverse), SortDescriptor(\MealLog.createdAt)])
    private var meals: [MealLog]
    @Environment(\.modelContext) private var context
    @State private var categoryID: UUID?
    @State private var adding = false
    @State private var editing: MealLog?

    private var days: [(day: Date, items: [MealLog])] {
        SearchEngine.filter(meals, query: "", categoryIDs: categoryID.map { [$0] } ?? [])
            .groupedByDay(\.day)
            .map { ($0.day, $0.items.sorted { $0.mealTime.order < $1.mealTime.order }) }
    }

    var body: some View {
        List {
            CategoryFilterBar(categories: meals.usedCategories, selection: $categoryID)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            ForEach(days, id: \.day) { group in
                Section(group.day.dayHeader) {
                    ForEach(group.items) { meal in
                        Button { editing = meal } label: { MealRow(meal: meal) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("삭제", systemImage: "trash", role: .destructive) { context.delete(meal) }
                            }
                            .contextMenu {
                                Button("편집", systemImage: "pencil") { editing = meal }
                                Button("삭제", systemImage: "trash", role: .destructive) { context.delete(meal) }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .emptyState {
            if meals.isEmpty {
                ContentUnavailableView("먹은 음식을 남겨보세요", systemImage: "fork.knife",
                                       description: Text("사진을 찍고 시간대와 메모를 함께 기록해요."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .trailing) {
                Button("식사 기록", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) {
            MealEditor(meal: nil, category: meals.usedCategories.first { $0.id == categoryID })
        }
        .sheet(item: $editing) { MealEditor(meal: $0) }
    }
}

struct MealRow: View {
    let meal: MealLog
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = Image(data: meal.photo) {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.primary.opacity(0.06)
                        Image(systemName: "fork.knife").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(showsDate ? "\(meal.day.dayHeader) \(meal.mealTime.label)" : meal.mealTime.label)
                    .font(.subheadline.weight(.semibold))
                if let memo = meal.title.nonEmpty {
                    Text(memo).lineLimit(2)
                }
                CategoryTags(categories: meal.categoryList)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

/// 새 식사 기록 또는 기존 기록 편집. 저장을 눌러야 반영됩니다.
struct MealEditor: View {
    private let meal: MealLog?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var photo: Data?
    @State private var day: Date
    @State private var mealTime: MealTime
    @State private var categories: [ItemCategory]
    @State private var memo: String
    @State private var pickerItem: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var showingCamera = false

    init(meal: MealLog?, category: ItemCategory? = nil) {
        self.meal = meal
        _photo = State(initialValue: meal?.photo)
        _day = State(initialValue: meal?.day ?? .now)
        _mealTime = State(initialValue: meal?.mealTime ?? .guess())
        _categories = State(initialValue: meal?.categoryList ?? (category.map { [$0] } ?? []))
        _memo = State(initialValue: meal?.title ?? "")
    }

    private var canSave: Bool { photo != nil || memo.nonEmpty != nil || !categories.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section { photoSection }
                Section("언제") {
                    DatePicker("날짜", selection: $day, displayedComponents: .date)
                    Picker("시간대", selection: $mealTime) {
                        ForEach(MealTime.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    CategoryDraftField(categories: $categories)
                    TextField("메모 · 무엇을 먹었나요?", text: $memo, axis: .vertical)
                }
                if let meal {
                    Section {
                        Button("기록 삭제", role: .destructive) {
                            context.delete(meal)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(meal == nil ? "식사 기록" : "식사 편집")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave || loadingPhoto)
                }
            }
            .onChange(of: pickerItem) { _, item in Task { await loadPhoto(item) } }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in setPhoto(data) }.ignoresSafeArea()
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private var photoSection: some View {
        if let image = Image(data: photo) {
            image.resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        } else if loadingPhoto {
            ProgressView().frame(maxWidth: .infinity, minHeight: 80)
        }
        HStack {
            #if os(iOS)
            if CameraPicker.isAvailable {
                Button("사진 찍기", systemImage: "camera") { showingCamera = true }
                Spacer()
            }
            #endif
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("앨범에서 고르기", systemImage: "photo.on.rectangle")
            }
            if photo != nil {
                Spacer()
                Button("지우기", systemImage: "trash", role: .destructive) { photo = nil }
                    .labelStyle(.iconOnly)
            }
        }
        .buttonStyle(.borderless)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loadingPhoto = true
        defer { loadingPhoto = false; pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        setPhoto(data)
    }

    private func setPhoto(_ data: Data) {
        photo = ImageUtil.downscaledJPEG(data, maxPixel: 1600) ?? data
    }

    private func save() {
        let target = meal ?? {
            let created = MealLog()
            context.insert(created)
            return created
        }()
        target.photo = photo
        target.day = Calendar.current.startOfDay(for: day)
        target.mealTime = mealTime
        target.categories = categories
        target.title = memo.nonEmpty ?? ""
        target.touch()
        dismiss()
    }
}

#if os(iOS)
/// 카메라로 바로 찍기. 찍은 사진을 JPEG로 넘깁니다.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
