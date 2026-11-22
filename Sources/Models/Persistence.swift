import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ItemCategory.self, Word.self, TodoItem.self, WikiNote.self, WikiImage.self, Bookmark.self,
         MealLog.self, Expense.self]
    }
}

enum SyncMode: String {
    case iCloud = "iCloud 동기화 중"
    case local = "이 기기에만 저장"
    case memory = "메모리(테스트)"
}

enum ModelContainerFactory {
    private(set) static var mode: SyncMode = .local

    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        if inMemory {
            mode = .memory
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: config)
        }
        if AppConfig.iCloudEnabled {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(AppConfig.iCloudContainer))
            if let container = try? ModelContainer(for: schema, configurations: config) {
                mode = .iCloud
                return container
            }
        }
        mode = .local
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("저장소를 열 수 없습니다: \(error)")
        }
    }
}

extension ModelContext {
    /// 이름이 같은 카테고리가 있으면 그것을, 없으면 새로 만들어 돌려줍니다.
    func category(named rawName: String) -> ItemCategory? {
        guard let name = rawName.nonEmpty else { return nil }
        let all = (try? fetch(FetchDescriptor<ItemCategory>())) ?? []
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let created = ItemCategory(name: name)
        insert(created)
        return created
    }
}
