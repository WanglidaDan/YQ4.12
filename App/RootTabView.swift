import SwiftUI

private enum RootTab: Hashable {
    case overview
    case schedule
    case clients
    case followUp
    case profile
}

struct RootTabView: View {
    let store: StudioStore
    @State private var selectedTab: RootTab = .overview

    init(store: StudioStore) {
        self.store = store
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TabView(selection: $selectedTab) {
                    Tab("工作台", systemImage: "square.grid.2x2.fill", value: .overview) {
                        overview
                    }

                    Tab("档期", systemImage: "calendar", value: .schedule) {
                        ScheduleView()
                    }

                    Tab("客户", systemImage: "person.2", value: .clients) {
                        ClientsView()
                    }

                    Tab("跟进", systemImage: "checklist", value: .followUp) {
                        followUp
                    }

                    Tab("我的", systemImage: "person.crop.circle", value: .profile) {
                        StandardProfileView()
                    }
                }
            } else {
                legacyTabView
            }
        }
        .tint(AppTheme.accent)
        .environment(store)
    }

    private var overview: some View {
        OverviewView(onOpenSchedule: { selectedTab = .schedule })
    }

    private var followUp: some View {
        FollowUpView(
            onOpenSchedule: { selectedTab = .schedule },
            onOpenClients: { selectedTab = .clients }
        )
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            overview
                .tabItem { Label("工作台", systemImage: "square.grid.2x2.fill") }
                .tag(RootTab.overview)

            ScheduleView()
                .tabItem { Label("档期", systemImage: "calendar") }
                .tag(RootTab.schedule)

            ClientsView()
                .tabItem { Label("客户", systemImage: "person.2") }
                .tag(RootTab.clients)

            followUp
                .tabItem { Label("跟进", systemImage: "checklist") }
                .tag(RootTab.followUp)

            StandardProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(RootTab.profile)
        }
    }
}
