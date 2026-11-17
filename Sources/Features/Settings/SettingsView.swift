import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(EnrichmentService.self) private var enrichment
    @Environment(CalendarEventStore.self) private var calendar
    @Environment(SyncMonitor.self) private var sync
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var exportDocument: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        @Bindable var enrichment = enrichment
        @Bindable var calendar = calendar
        Form {
            Section {
                Picker("단어 정리에 쓸 AI", selection: $enrichment.provider) {
                    ForEach(AIProvider.allCases) { Text($0.label).tag($0) }
                }
                ForEach(AIProvider.allCases) { provider in
                    LabeledContent(provider.label, value: enrichment.availability(of: provider) ?? "사용 가능")
                        .font(.footnote)
                }
                if enrichment.provider == .gemini {
                    LabeledContent("모델", value: AppConfig.geminiModel).font(.footnote)
                }
            } header: {
                Text("AI")
            } footer: {
                Text("Gemini 키와 모델은 Config/Env.xcconfig에서 바꿉니다.")
            }

            Section("캘린더") {
                Toggle("기본 캘린더 일정 함께 보기", isOn: $calendar.isEnabled)
                    .monochromeToggle()
                LabeledContent("권한", value: calendar.statusDescription).font(.footnote)
            }

            Section("카테고리") {
                NavigationLink("카테고리 관리") { CategoryManager() }
            }

            Section {
                Button("내보내기 (JSON + Markdown)", systemImage: "square.and.arrow.up") { export() }
                Button("가져오기", systemImage: "square.and.arrow.down") { importing = true }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("백업")
            } footer: {
                Text("index.json에 전체 구조와 id가, 항목마다 .md 파일이 담긴 폴더로 저장됩니다. 가져오면 같은 id는 더 최근 것으로 맞춥니다.")
            }

            Section {
                LabeledContent("저장 방식", value: ModelContainerFactory.mode.rawValue)
                if ModelContainerFactory.mode == .iCloud {
                    LabeledContent("iCloud 계정", value: sync.accountStatus)
                    LabeledContent("마지막 동기화", value: sync.lastEvent ?? "아직 없음")
                    if let error = sync.lastError {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("동기화")
            } footer: {
                Text("같은 Apple 계정으로 로그인한 기기끼리 자동으로 맞춰집니다. 앱이 켜져 있을 때 몇 초~몇 분 안에 반영돼요.")
            }
        }
        .formStyle(.grouped)
        .tint(.primary)
        .navigationTitle("설정")
        .inlineTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            #endif
        }
        .task { await sync.refreshAccount() }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .folder,
                      defaultFilename: BackupService.defaultFolderName()) { result in
            if case .failure(let error) = result { message = "내보내기 실패: \(error.localizedDescription)" }
            else { message = "내보냈습니다." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): restore(from: url)
            case .failure(let error): message = "가져오기 실패: \(error.localizedDescription)"
            }
        }
    }

    private func export() {
        do {
            exportDocument = BackupDocument(wrapper: try BackupService.makeBackup(from: context))
            exporting = true
        } catch {
            message = "내보내기 실패: \(error.localizedDescription)"
        }
    }

    private func restore(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let wrapper = try FileWrapper(url: url, options: .immediate)
            let summary = try BackupService.restore(from: wrapper, into: context)
            message = summary.description
        } catch {
            message = "가져오기 실패: \(error.localizedDescription)"
        }
    }
}

private struct CategoryManager: View {
    @Query(sort: \ItemCategory.name) private var categories: [ItemCategory]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(categories) { category in
                CategoryNameRow(category: category)
            }
            .onDelete { $0.map { categories[$0] }.forEach(context.delete) }
        }
        .emptyState {
            if categories.isEmpty { ContentUnavailableView("카테고리가 없어요", systemImage: "number") }
        }
        .navigationTitle("카테고리")
    }
}

private struct CategoryNameRow: View {
    @Bindable var category: ItemCategory

    var body: some View {
        HStack {
            TextField("이름", text: $category.name)
            Text("\(category.itemCount)").foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
