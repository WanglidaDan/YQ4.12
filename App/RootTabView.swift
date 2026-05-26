import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case overview
    case schedule
    case clients
    case profile
}

private enum CustomerWorkspaceMode: String, CaseIterable, Identifiable {
    case clients
    case followUp
    case team

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clients: "客户"
        case .followUp: "跟进"
        case .team: "团队"
        }
    }

    var headline: String {
        switch self {
        case .clients: "客户资产"
        case .followUp: "跟进节奏"
        case .team: "团队分工"
        }
    }

    var subtitle: String {
        switch self {
        case .clients: "统一查看客户资料、等级和业务来源"
        case .followUp: "把待沟通、待确认、待回款串成一条线"
        case .team: "按成员看今日安排和拍摄责任"
        }
    }

    var symbolName: String {
        switch self {
        case .clients: "person.text.rectangle.fill"
        case .followUp: "bubble.left.and.bubble.right.fill"
        case .team: "person.3.fill"
        }
    }
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
    @State private var customerWorkspaceMode: CustomerWorkspaceMode = .clients
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

                CustomerWorkspaceView(
                    mode: $customerWorkspaceMode,
                    onOpenSchedule: { selectedTab = .schedule }
                )
                .tabItem {
                    Label("关系", systemImage: "person.2")
                }
                .tag(RootTab.clients)

                SettingsView(showsCloseButton: false)
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
            guard newValue != .overview else { return }
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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

private struct CustomerWorkspaceView: View {
    @Binding var mode: CustomerWorkspaceMode
    let onOpenSchedule: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .clients:
                ClientsView()
            case .followUp:
                FollowUpView(onOpenSchedule: onOpenSchedule, onOpenClients: { mode = .clients })
            case .team:
                TeamView(onOpenSchedule: onOpenSchedule)
            }
        }
        .safeAreaInset(edge: .top) {
            relationshipModeHeader
        }
    }

    private var relationshipModeHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.headline)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(mode.subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Picker("客户与团队", selection: $mode) {
                ForEach(CustomerWorkspaceMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(AppTheme.line.opacity(0.68))
        }
    }
}

struct TeamView: View {
    @Environment(StudioStore.self) private var store

    let onOpenSchedule: () -> Void

    @State private var showingNewCrewMember = false
    @State private var editingCrewMember: CrewMemberRecord?

    private var todayBookings: [BookingRecord] {
        store.bookings(on: .now)
    }

    private var isTeamModeEnabled: Bool {
        store.settings.studioModeEnabled
    }

    private var currentCrewMemberName: String? {
        store.preferredCrewMemberName
    }

    private var myTodayBookings: [BookingRecord] {
        guard let memberName = currentCrewMemberName else { return [] }
        return store.bookings(on: .now, assignedTo: memberName)
    }

    private var otherTodayBookings: [BookingRecord] {
        guard currentCrewMemberName != nil else { return todayBookings }
        let myIDs = Set(myTodayBookings.map(\.id))
        return todayBookings.filter { myIDs.contains($0.id) == false }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    premiumHeroHeader
                    summarySection
                    dispatchSection
                    teamPreferencesSection
                    rosterSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("团队")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewCrewMember) {
                TeamMemberEditorView()
                    .environment(store)
            }
            .sheet(item: $editingCrewMember) { member in
                TeamMemberEditorView(member: member)
                    .environment(store)
            }
        }
    }

    private var premiumHeroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.accentWarmSoft)
                        .frame(width: 54, height: 54)
                    Image(systemName: isTeamModeEnabled ? "person.3.sequence.fill" : "person.crop.circle")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWarmDeep)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(isTeamModeEnabled ? "团队协作视图" : "个人工作视图")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppTheme.ink)
                    Text(isTeamModeEnabled ? "把今日排班、我的分工和成员设置放到同一页。" : "当前保持个人模式，仍可先维护成员资料。")
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                statusChip(title: "成员 \(store.activeCrewMembers.count)", systemImage: "person.2.fill", tint: AppTheme.accent)
                statusChip(title: "今日 \(todayBookings.count)", systemImage: "calendar", tint: AppTheme.info)
                if let currentCrewMemberName {
                    statusChip(title: currentCrewMemberName, systemImage: "scope", tint: AppTheme.accentWarmDeep)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(style: .emphasized)
    }

    private var summarySection: some View {
        AppInfoCard(title: "团队工作台", subtitle: isTeamModeEnabled ? "今日排班、成员设置和协作权限集中管理。" : "当前为个人模式，可先开启团队模式再分配成员。") {
            HStack(spacing: 12) {
                AppMetricTile(title: "团队成员", value: "\(store.activeCrewMembers.count)", subtitle: isTeamModeEnabled ? "团队模式已开启" : "团队模式未开启", fillColor: AppTheme.panelStrong)
                AppMetricTile(title: "今日安排", value: "\(todayBookings.count)", subtitle: currentCrewMemberName == nil ? "全部档期" : "含我的安排", fillColor: AppTheme.panelStrong)
            }

            Button("打开档期") {
                onOpenSchedule()
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
    }

    private var dispatchSection: some View {
        GlassCard(title: isTeamModeEnabled ? "团队分工" : "今日安排", subtitle: dispatchSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
                if isTeamModeEnabled, let currentCrewMemberName {
                    AppInlineNote(systemImage: "person.crop.circle.fill", text: "当前成员：\(currentCrewMemberName)")
                } else if isTeamModeEnabled {
                    AppInlineNote(systemImage: "person.crop.circle.badge.questionmark", text: "未选择当前成员，先在下方团队设置里指定自己是谁。")
                } else {
                    AppInlineNote(systemImage: "calendar", text: "当前为个人模式，这里直接展示今天全部安排。")
                }

                if todayBookings.isEmpty {
                    AppEmptyState(title: "今天暂无拍摄安排", subtitle: "当日有多场拍摄时，这里会直接告诉你自己该去哪场、团队其他人在拍什么。", systemImage: "calendar")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if let currentCrewMemberName, myTodayBookings.isEmpty {
                            AppInlineNote(systemImage: "person.crop.circle.badge.xmark", text: "\(currentCrewMemberName) 今天暂未被分配，继续看团队其他安排。")
                        }
                        if currentCrewMemberName != nil, myTodayBookings.isEmpty == false {
                            dispatchGroup(title: "我的安排", bookings: myTodayBookings, highlight: true)
                        }
                        if otherTodayBookings.isEmpty == false {
                            dispatchGroup(title: isTeamModeEnabled ? "团队其他安排" : "今日安排", bookings: otherTodayBookings, highlight: false)
                        }
                    }
                }
            }
        }
    }

    private var teamPreferencesSection: some View {
        GlassCard(title: "团队设置", subtitle: "切换团队模式，并指定当前成员。") {
            VStack(alignment: .leading, spacing: 12) {
                toggleRow(title: "团队模式", subtitle: "开启后可以按成员分配拍摄任务。", isOn: binding(for: \.studioModeEnabled))

                toggleRow(title: "高亮我的分工", subtitle: "在团队视角下优先显示属于我的安排。", isOn: binding(for: \.crewLensEnabled))
                    .disabled(store.settings.studioModeEnabled == false)

                HStack(spacing: 12) {
                    Text("当前成员")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Picker("当前成员", selection: binding(for: \.currentCrewMemberID)) {
                        Text("未选择").tag(Optional<UUID>.none)
                        ForEach(store.activeCrewMembers) { member in
                            Text(member.displayName).tag(Optional(member.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("临时成员名")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    TextField(
                        "兼容旧数据或临时身份",
                        text: Binding(
                            get: { store.settings.currentMemberName },
                            set: { newValue in
                                updateSettings { settings in
                                    settings.currentMemberName = newValue
                                }
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.ink)
                    .disabled(store.settings.studioModeEnabled == false)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            }
        }
    }

    private var rosterSection: some View {
        GlassCard(title: "团队成员", subtitle: "管理参与拍摄的成员信息。") {
            VStack(alignment: .leading, spacing: 12) {
                if store.activeCrewMembers.isEmpty {
                    AppInlineNote(systemImage: "person.2.slash", text: "先添加团队成员，后续分工就能直接指定谁去拍哪场。")
                } else {
                    ForEach(store.activeCrewMembers) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Text(String(member.displayName.prefix(1)))
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.accent)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.displayName)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                                Text(memberSubtitle(for: member))
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            Button("编辑") {
                                editingCrewMember = member
                            }
                            .buttonStyle(AppGhostButtonStyle())

                            Button("归档", role: .destructive) {
                                store.archiveCrewMember(member.id)
                            }
                            .buttonStyle(AppGhostButtonStyle())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                }

                Button {
                    showingNewCrewMember = true
                } label: {
                    Label("新增团队成员", systemImage: "person.badge.plus")
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }

    private var dispatchSubtitle: String {
        if isTeamModeEnabled == false {
            return todayBookings.isEmpty ? "当前没有排班" : "个人模式下按今日日期聚合全部项目。"
        }
        if currentCrewMemberName != nil {
            return todayBookings.isEmpty ? "当前没有排班" : "快速查看我的安排与团队其他安排。"
        }
        return todayBookings.isEmpty ? "当前没有排班" : "适合工作室快速查看我的安排与团队其他安排。"
    }

    private func dispatchGroup(title: String, bookings: [BookingRecord], highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(bookings.count) 场")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            VStack(spacing: 10) {
                ForEach(bookings) { booking in
                    dispatchRow(booking, highlight: highlight)
                }
            }
        }
    }

    private func dispatchRow(_ booking: BookingRecord, highlight: Bool) -> some View {
        let personalSummary = currentCrewMemberName.flatMap { memberName in
            let assignments = store.assignments(for: booking, matching: memberName)
            return assignments.isEmpty ? nil : assignments.map(\.operationalSummaryText).joined(separator: " / ")
        }
        let teamSummary = (isTeamModeEnabled && booking.crewAssignments.isEmpty == false) ? crewAssignmentSummary(for: booking) : nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if highlight {
                    Text("我的安排")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentSurface, in: Capsule())
                }
            }

            Text(booking.title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.clientName(for: booking))
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)

            Text(booking.venue.isEmpty ? booking.fullAddressText : booking.venue)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)

            if let personalSummary {
                AppInlineNote(systemImage: "person.crop.circle.badge.checkmark", text: personalSummary, tint: AppTheme.accentWarmDeep)
            } else if let teamSummary {
                AppInlineNote(systemImage: "person.3.fill", text: teamSummary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(highlight ? AppTheme.accentSoft.opacity(0.9) : AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke((highlight ? AppTheme.accent.opacity(0.22) : AppTheme.line.opacity(0.55)), lineWidth: 1)
        }
    }

    private func binding<Value>(for keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var updated = store.settings
        mutate(&updated)
        store.updateSettings(updated)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func statusChip(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(tint.opacity(0.1), in: Capsule())
    }

    private func crewAssignmentSummary(for booking: BookingRecord) -> String {
        let normalized = BookingCrewAssignment.normalized(booking.crewAssignments)
        guard normalized.isEmpty == false else { return "待安排" }

        let heads = normalized.prefix(2).map { "\($0.displayName)·\($0.role.title)" }
        if normalized.count > 2 {
            return heads.joined(separator: "、") + "、+\(normalized.count - 2)"
        }
        return heads.joined(separator: "、")
    }

    private func memberSubtitle(for member: CrewMemberRecord) -> String {
        let contact = member.phone.isEmpty ? member.email : member.phone
        let contactText = contact.isEmpty ? "暂无联系方式" : contact
        if member.roleTitle.isEmpty { return contactText }
        return "\(member.roleTitle) · \(contactText)"
    }
}
