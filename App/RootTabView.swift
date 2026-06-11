import SwiftUI
import UIKit

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
        Self.configureTabBarAppearance()
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

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: "#161816").withAlphaComponent(0.86)
            }
            return UIColor.white.withAlphaComponent(0.82)
        }
        appearance.shadowColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: "#343734").withAlphaComponent(0.72)
            }
            return UIColor(hex: "#D9D5CF").withAlphaComponent(0.38)
        }
        appearance.selectionIndicatorImage = selectionIndicatorImage()

        let selectedColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: "#D6E0D4")
            }
            return UIColor(hex: "#264735")
        }
        let normalColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: "#909791")
            }
            return UIColor(hex: "#6B6B6B")
        }
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = normalAttributes
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = selectedAttributes
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func selectionIndicatorImage() -> UIImage? {
        let tabCount: CGFloat = 4
        let totalWidth = UIScreen.main.bounds.width - 32
        let itemWidth = max((totalWidth / tabCount) - 10, 64)
        let size = CGSize(width: itemWidth, height: 54)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 4)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 24)
            UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(hex: "#2B312D").withAlphaComponent(0.92)
                }
                return UIColor(hex: "#DDE8DC").withAlphaComponent(0.70)
            }.setFill()
            path.fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24))
    }

}
