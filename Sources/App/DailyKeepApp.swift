import SwiftData
import SwiftUI

@main
struct DailyKeepApp: App {
    private let container = ModelContainerFactory.make()
    @State private var router = AppRouter()
    @State private var enrichment = EnrichmentService()
    @State private var calendar = CalendarEventStore()
    /// container가 먼저 만들어져야 동기화 방식을 알 수 있어 그 뒤에 둡니다
    @State private var sync = SyncMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(enrichment)
                .environment(calendar)
                .environment(sync)
                #if DEBUG
                .onAppear { SampleData.seedIfRequested(container.mainContext) }
                #endif
                #if os(macOS)
                // 달력과 일정이 나란히 들어갈 최소 크기
                .frame(minWidth: 760, minHeight: 520)
                #endif
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(enrichment)
                .environment(calendar)
                .environment(sync)
                .frame(width: 520, height: 560)
        }
        .modelContainer(container)
        #endif
    }
}

enum AppTab: Hashable {
    case words, todo, wiki, links, search
}

@Observable
final class AppRouter {
    var tab: AppTab = .words
    var showSettings = false
}
