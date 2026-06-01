import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case overview
    case schedule
    case clients
    case profile
}

private enum QuickActionDestination: String, Identifiable {
    case booking
    case client
    case touchpoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .booking: "新建档期"
        case .client: "新增客户"
        case .touchpoint: "新增跟进"
        }
    }

    var symbolName: String {
        switch self {
        case .booking: "calendar.badge.plus"
        case .client: "person.crop.circle.badge.plus"
        case .touchpoint: "bubble.left.and.bubble.right.fill"
        }
    }

    var tint: Color {
        switch self {
        case .booking: AppTheme.accent
        case .client: AppTheme.info
        case .touchpoint: AppTheme.accentWarmDeep
        }
    }
}

struct RootTabView: View {
    let store: StudioStore
    @State private var selectedTab: RootTab = .overview
    @State private var showingQuickActions = false
    @State private var quickActionDestination: QuickActionDestination?
    @State private var isPresentingQuickActionSheet = false
    @State private var quickActionPresentationTask: Task<Void, Never>?

    init(store: StudioStore) {
        self.store = store
        Self.configureTabBarAppearance()
    }

    private var shouldShowQuickActionButton: Bool {
        selectedTab == .schedule
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                OverviewView(
                    onOpenSchedule: { selectedTab = .schedule }
                )
                .tabItem {
                    Label("工作台", systemImage: "square.grid.2x2.fill")
                }
                .tag(RootTab.overview)

                ScheduleView(
                    quickActionsExpanded: showingQuickActions,
                    quickActionDisabled: isPresentingQuickActionSheet,
                    onQuickActionButtonTap: toggleQuickActions
                )
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

            if shouldShowQuickActionButton && showingQuickActions {
                Rectangle()
                    .fill(AppTheme.background.opacity(0.72))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            showingQuickActions = false
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("关闭快捷新建菜单")
                    .accessibilityHint("轻点收起快捷新建菜单")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
            }

            if shouldShowQuickActionButton && showingQuickActions {
                quickActionMenu
                    .padding(.top, 80)
                    .padding(.trailing, 12)
                    .zIndex(1)
            }
        }
        .tint(AppTheme.accentWarmDeep)
        .environment(store)
        .onChange(of: selectedTab) { _, newValue in
            guard newValue != .schedule else { return }
            quickActionPresentationTask?.cancel()
            quickActionPresentationTask = nil
            showingQuickActions = false
            if quickActionDestination == nil {
                isPresentingQuickActionSheet = false
            }
        }
        .sheet(item: $quickActionDestination, onDismiss: {
            quickActionPresentationTask?.cancel()
            quickActionPresentationTask = nil
            quickActionDestination = nil
            isPresentingQuickActionSheet = false
        }) { destination in
            switch destination {
            case .booking:
                BookingEditorView()
                    .environment(store)
            case .client:
                ClientEditorView()
                    .environment(store)
            case .touchpoint:
                TouchpointEditorView()
                    .environment(store)
            }
        }
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
                return UIColor(hex: "#D8CEC2").withAlphaComponent(0.52)
            }.setFill()
            path.fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24))
    }

    private var quickActionMenu: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accentWarmDeep)
                Text("快捷新建")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.line.opacity(0.82), lineWidth: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))

            ForEach([QuickActionDestination.touchpoint, .client, .booking]) { item in
                Button {
                    presentQuickAction(item)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(item.tint.opacity(0.12))
                                .frame(width: 36, height: 36)

                            Image(systemName: item.symbolName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(item.tint)
                        }

                        Text(item.title)
                            .font(AppTypography.bodyStrong)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 16)
                    .frame(width: 184, height: 52)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.82), lineWidth: 1)
                    }
                    .shadow(color: AppTheme.cardShadow, radius: AppShadow.cardRadius, y: AppShadow.cardY)
                }
                .buttonStyle(.plain)
                .disabled(isPresentingQuickActionSheet)
                .accessibilityLabel(item.title)
                .accessibilityHint("打开\(item.title)表单")
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func toggleQuickActions() {
        guard isPresentingQuickActionSheet == false else { return }
        quickActionPresentationTask?.cancel()
        AppHaptics.tapLight()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            showingQuickActions.toggle()
        }
    }

    private func presentQuickAction(_ destination: QuickActionDestination) {
        guard isPresentingQuickActionSheet == false else { return }

        isPresentingQuickActionSheet = true
        quickActionPresentationTask?.cancel()
        AppHaptics.impactMedium()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            showingQuickActions = false
        }

        quickActionPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard Task.isCancelled == false else { return }
            quickActionDestination = destination
            quickActionPresentationTask = nil
        }
    }
}
