import SwiftData
import SwiftUI

@main
struct DailyKeepApp: App {
    private let container = ModelContainerFactory.make()
    @State private var router = AppRouter()
    @State private var enrichment = EnrichmentService()
    @State private var calendar = CalendarEventStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(enrichment)
                .environment(calendar)
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
