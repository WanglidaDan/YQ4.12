import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case overview
    case schedule
    case clients
    case followUp
    case profile
}

struct RootTabView: View {
    let store: StudioStore
    @AppStorage("profileAvatarData") private var avatarData = Data()
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
                    Label("客户", systemImage: "person.2")
                }
                .tag(RootTab.clients)

            FollowUpView(
                onOpenSchedule: { selectedTab = .schedule },
                onOpenClients: { selectedTab = .clients }
            )
            .tabItem {
                Label("跟进", systemImage: "checklist")
            }
            .tag(RootTab.followUp)

            StandardProfileView()
                .tabItem {
                    if let tabAvatarImage {
                        Image(uiImage: tabAvatarImage)
                        Text("我的")
                    } else {
                        Label("我的", systemImage: "person.crop.circle")
                    }
                }
                .tag(RootTab.profile)
        }
        .tint(AppTheme.accent)
        .environment(store)
    }

    private var tabAvatarImage: UIImage? {
        guard let source = UIImage(data: avatarData) else { return nil }

        let size = CGSize(width: 27, height: 27)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let bounds = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: bounds).addClip()

            let scale = max(size.width / source.size.width, size.height / source.size.height)
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
