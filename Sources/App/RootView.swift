import SwiftUI

/// 탐색 컨테이너: TabView(넓은 화면·맥에선 사이드바) → 탭마다 NavigationStack
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab(ItemKind.word.label, systemImage: ItemKind.word.systemImage, value: AppTab.words) {
                NavigationStack { WordsView() }
            }
            Tab(ItemKind.todo.label, systemImage: ItemKind.todo.systemImage, value: AppTab.todo) {
                NavigationStack { TodoTab() }
            }
            Tab(ItemKind.wiki.label, systemImage: ItemKind.wiki.systemImage, value: AppTab.wiki) {
                NavigationStack { WikiListView() }
            }
            Tab(ItemKind.link.label, systemImage: ItemKind.link.systemImage, value: AppTab.links) {
                NavigationStack { LinksView() }
            }
            Tab("검색", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                NavigationStack { GlobalSearchView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.primary)
        // 어느 화면이든 빈 곳을 누르거나 목록을 스크롤하면 키보드가 닫힙니다
        .dismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.immediately)
        .sheet(isPresented: $router.showSettings) {
            NavigationStack { SettingsView() }
        }
    }
}

/// 각 탭 루트 툴바의 설정 버튼(iOS). 맥은 ⌘, 설정 창을 씁니다.
extension View {
    func settingsToolbar() -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItem(placement: .topBarLeading) { SettingsButton() }
        }
        #else
        self
        #endif
    }
}

private struct SettingsButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button("설정", systemImage: "gearshape") { router.showSettings = true }
    }
}
