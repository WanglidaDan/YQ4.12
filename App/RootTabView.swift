import SwiftUI

private enum RootTab: Hashable {
    case overview
    case schedule
    case clients
    case profile
}

struct RootTabView: View {
    let store: StudioStore
    @State private var selectedTab: RootTab = .overview

    init(store: StudioStore) {
        self.store = store
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                onOpenSchedule: { selectedTab = .schedule }
            )
            .tabItem {
                Label("工作台", systemImage: "square.grid.2x2.fill")
            }
            .tag(RootTab.overview)

            ScheduleView()
                .tabItem {
                    Label("档期", systemImage: "calendar")
                }
                .tag(RootTab.schedule)

            ClientsView()
                .tabItem {
                    Label("关系", systemImage: "person.2")
                }
                .tag(RootTab.clients)

            StandardProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(RootTab.profile)
        }
        .tint(AppTheme.accent)
        .environment(store)
    }
}
