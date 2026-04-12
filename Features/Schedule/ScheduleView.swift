import SwiftUI

private enum ScheduleFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case attention
    case delivered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .active: "活跃"
        case .attention: "待处理"
        case .delivered: "已交付"
        }
    }
}

private enum ScheduleViewMode: String, CaseIterable, Identifiable {
    case month
    case week
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "月"
        case .week: "周"
        case .list: "列表"
        }
    }
}

private enum ScheduleScope: String, CaseIterable, Identifiable {
    case active
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "主列表"
        case .archived: "归档"
        }
    }
}

private struct ScheduleRoute: Hashable {
    let bookingID: UUID
}

private typealias BookingDayGroup = (date: Date, bookings: [BookingRecord])

private enum SchedulePalette {
    static let background = AppTheme.background
    static let panel = AppTheme.panel
    static let panelSoft = AppTheme.panelSoft
    static let panelMuted = AppTheme.panelSoft
    static let line = AppTheme.line
    static let ink = AppTheme.ink
    static let secondary = AppTheme.secondaryInk
    static let muted = AppTheme.mutedInk
    static let green = AppTheme.accent
    static let greenDeep = AppTheme.accentDeep
    static let accent = AppTheme.accentWarmDeep
    static let portrait = AppTheme.accentRose
    static let tabGold = AppTheme.accentWarmSoft
    static let shadow = AppTheme.cardShadow
}

struct ScheduleView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    let quickActionsExpanded: Bool
    let quickActionDisabled: Bool
    let onQuickActionButtonTap: () -> Void

    @State private var filter: ScheduleFilter = .all
    @State private var viewMode: ScheduleViewMode = .month
    @State private var scope: ScheduleScope = .active
    @State private var searchText = ""
    @State private var editingBooking: BookingRecord?
    @State private var focusDate = Date()
    @State private var deletingBooking: BookingRecord?
    @State private var showingFilterSheet = false
    @State private var showingSearchSheet = false
    @State private var showingMonthInsightSheet = false
    @State private var showingCreateBookingSheet = false
    @State private var didAnimateIn = false

    private let calendar = Calendar.current

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceBookings: [BookingRecord] {
        switch scope {
        case .active:
            store.activeBookings
        case .archived:
            store.archivedBookings
        }
    }

    private var filteredBookings: [BookingRecord] {
        sourceBookings.filter { booking in
            matches(filter: filter, booking: booking) && matches(keyword: searchText, booking: booking)
        }
    }

    private var monthContextBookings: [BookingRecord] {
        filteredBookings.filter {
            calendar.isDate($0.startAt, equalTo: focusDate, toGranularity: .month) &&
            calendar.isDate($0.startAt, equalTo: focusDate, toGranularity: .year)
        }
    }

    private var bookingsByStartDay: [Date: [BookingRecord]] {
        Dictionary(grouping: filteredBookings) { calendar.startOfDay(for: $0.startAt) }
    }

    private var monthBookingsByStartDay: [Date: [BookingRecord]] {
        Dictionary(grouping: monthContextBookings) { calendar.startOfDay(for: $0.startAt) }
    }

    private var bookingsForFocusDate: [BookingRecord] {
        bookingsByStartDay[calendar.startOfDay(for: focusDate), default: []]
            .sorted { $0.startAt < $1.startAt }
    }

    private var isTeamModeEnabled: Bool {
        store.settings.studioModeEnabled
    }

    private var currentCrewMemberName: String? {
        store.preferredCrewMemberName
    }

    private var knownCrewMemberNames: [String] {
        guard isTeamModeEnabled else { return [] }
        return store.activeCrewMemberNames
    }

    private var personalFocusBookings: [BookingRecord] {
        guard let memberName = currentCrewMemberName else { return [] }
        return bookingsForFocusDate.filter { store.assignments(for: $0, matching: memberName).isEmpty == false }
    }

    private var otherFocusBookings: [BookingRecord] {
        guard let memberName = currentCrewMemberName else { return [] }
        return bookingsForFocusDate.filter { store.assignments(for: $0, matching: memberName).isEmpty }
    }

    private var groupedBookings: [BookingDayGroup] {
        bookingsByStartDay
            .map { key, value in
                (date: key, bookings: value.sorted { $0.startAt < $1.startAt })
            }
            .sorted { $0.date < $1.date }
    }

    private var monthConflictDates: Set<Date> {
        Set(monthBookingsByStartDay.compactMap { key, value in value.count > 1 ? key : nil })
    }

    private var conflictDates: Set<Date> {
        Set(bookingsByStartDay.compactMap { key, value in value.count > 1 ? key : nil })
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: focusDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDay) else {
            return []
        }
        return stride(from: firstWeek.start, to: lastWeek.end, by: 60 * 60 * 24).map { $0 }
    }

    private var visibleDates: [Date] {
        viewMode == .month ? monthDates : weekDates
    }

    private var calendarRows: [[Date]] {
        stride(from: 0, to: visibleDates.count, by: 7).map { start in
            Array(visibleDates[start..<min(start + 7, visibleDates.count)])
        }
    }

    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: focusDate) else { return [] }
        return stride(from: weekInterval.start, to: weekInterval.end, by: 60 * 60 * 24).map { $0 }
    }

    private var pastBookingsCount: Int {
        let todayStart = calendar.startOfDay(for: .now)
        return filteredBookings.filter { $0.endAt < todayStart }.count
    }

    private var todayBookingsCount: Int {
        filteredBookings.filter { calendar.isDateInToday($0.startAt) }.count
    }

    private var upcomingBookingsCount: Int {
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return filteredBookings.filter { $0.startAt >= tomorrowStart }.count
    }

    private var focusMyAssignmentsCount: Int {
        personalFocusBookings.count
    }

    private var filterSummary: String {
        [
            "范围：\(scope.title)",
            "筛选：\(filter.title)",
            "视图：\(viewMode.title)"
        ].joined(separator: " · ")
    }

    private var pageBackground: some View {
        ZStack {
            SchedulePalette.background

            LinearGradient(
                colors: [
                    colorScheme == .dark ? AppTheme.panel.opacity(0.16) : Color.white.opacity(0.72),
                    SchedulePalette.background.opacity(0.96),
                    colorScheme == .dark ? AppTheme.canvas.opacity(0.92) : Color(uiColor: UIColor(hex: "#F4F4F0")).opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    colorScheme == .dark ? AppTheme.accentSoft.opacity(0.16) : Color.white.opacity(0.62),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    colorScheme == .dark ? AppTheme.panelSoft.opacity(0.22) : Color(uiColor: UIColor(hex: "#EEF2EE")).opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                calendarDashboard
            }
            .navigationDestination(for: ScheduleRoute.self) { route in
                BookingDetailView(bookingID: route.bookingID)
            }
            .sheet(item: $editingBooking) { booking in
                BookingEditorView(booking: booking)
            }
            .sheet(isPresented: $showingCreateBookingSheet) {
                BookingEditorView()
            }
            .sheet(isPresented: $showingSearchSheet) {
                ScheduleSearchSheet(
                    searchText: $searchText,
                    bookings: filteredBookings,
                    scope: scope
                )
            }
            .sheet(isPresented: $showingMonthInsightSheet) {
                ScheduleTimelineInsightSheet(
                    focusDate: focusDate,
                    bookings: monthContextBookings,
                    conflictCount: monthConflictDates.count
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                ScheduleFilterSheet(
                    searchText: $searchText,
                    filter: $filter,
                    viewMode: $viewMode,
                    scope: $scope,
                    summary: filterSummary,
                    onReset: {
                        filter = .all
                        scope = .active
                        viewMode = .month
                        searchText = ""
                    }
                )
            }
            .navigationTitle("档期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        AppHaptics.tapLight()
                        showingSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开搜索")

                    Button {
                        AppHaptics.tapLight()
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开筛选")
                }
            }
            .confirmationDialog("确认删除这个档期？", isPresented: Binding(
                get: { deletingBooking != nil },
                set: { if $0 == false { deletingBooking = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let deletingBooking {
                        store.deleteBooking(deletingBooking.id)
                    }
                    deletingBooking = nil
                }
                Button("取消", role: .cancel) {
                    deletingBooking = nil
                }
            } message: {
                Text("删除后订单与关联付款流水将一并移除，且无法恢复。")
            }
            .onChange(of: viewMode) { _, _ in
                AppHaptics.selection()
            }
            .onChange(of: filter) { _, _ in
                AppHaptics.selection()
            }
            .onChange(of: scope) { _, _ in
                AppHaptics.selection()
            }
            .onAppear {
                guard didAnimateIn == false else { return }
                withAnimation(.easeOut(duration: 0.42)) {
                    didAnimateIn = true
                }
            }
        }
    }

    private var calendarDashboard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                dashboardHeader
                monthOverviewCard
                todayAgendaCard
                scheduleBoardCard
                teamDispatchCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 132)
            .opacity(didAnimateIn ? 1 : 0.82)
            .offset(y: didAnimateIn ? 0 : 10)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 104)
        }
    }

    private var dashboardHeader: some View {
        Color.clear
            .frame(height: 0)
    }

    private var monthOverviewCard: some View {
        Button {
            AppHaptics.impactMedium()
            showingMonthInsightSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("档期概览")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(SchedulePalette.ink)
                    Spacer()
                    Text("查看概览")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SchedulePalette.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    overviewMetricBlock(value: "\(pastBookingsCount)", title: "历史档期")
                    overviewMetricBlock(value: "\(todayBookingsCount)", title: "今日安排")
                    overviewMetricBlock(value: "\(upcomingBookingsCount)", title: "未来档期")
                    overviewMetricBlock(value: "\(focusMyAssignmentsCount)", title: "我的安排")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardSurface(cornerRadius: 30, fillColor: Color.white.opacity(0.9), strokeOpacity: 0.74)
        }
        .buttonStyle(.plain)
    }

    private var teamDispatchCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isTeamModeEnabled ? "分工聚焦" : "当天安排")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(SchedulePalette.ink)
                }

                Spacer(minLength: 12)

                if knownCrewMemberNames.isEmpty == false {
                    Menu {
                        Button("全部成员") {
                            applyCrewLens(nil)
                        }
                        ForEach(knownCrewMemberNames, id: \.self) { name in
                            Button(name) {
                                applyCrewLens(name)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 13, weight: .semibold))
                            Text(currentCrewMemberName ?? "全部成员")
                                .font(AppTypography.meta.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(SchedulePalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SchedulePalette.panelSoft, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(SchedulePalette.line.opacity(0.9), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if bookingsForFocusDate.isEmpty {
                AppInlineNote(systemImage: "calendar.badge.exclamationmark", text: scope == .active ? "这一天还没有档期，选中有拍摄的日期后，这里会自动分出“我负责”和“团队其他”。" : "当前日期没有归档项目。")
            } else if let memberName = currentCrewMemberName {
                if personalFocusBookings.isEmpty {
                    AppInlineNote(systemImage: "person.crop.circle.badge.xmark", text: "\(memberName) 这一天没有被分配到场次，下面继续看团队其他安排。")
                } else {
                    VStack(spacing: 10) {
                        ForEach(personalFocusBookings) { booking in
                            focusAssignmentCard(booking, isMine: true)
                        }
                    }
                }

                if otherFocusBookings.isEmpty == false {
                    Divider()
                        .overlay(SchedulePalette.line.opacity(0.78))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("团队其他")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(SchedulePalette.secondary)
                        ForEach(otherFocusBookings.prefix(3)) { booking in
                            focusAssignmentCard(booking, isMine: false)
                        }
                    }
                }
            } else {
                AppInlineNote(systemImage: "sparkles", text: isTeamModeEnabled ? (knownCrewMemberNames.isEmpty ? "当前档期还没有成员分工。录入成员后，这里会自动告诉每个人该去哪场。" : "点右上角选择成员后，这里会切成“我负责”的视角。") : "当前为个人模式，这里按日期展示全部安排，不再拆分“我负责”和“团队其他”。")
                VStack(spacing: 10) {
                    ForEach(bookingsForFocusDate.prefix(3)) { booking in
                        focusAssignmentCard(booking, isMine: false)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 28, fillColor: SchedulePalette.panel, strokeOpacity: 0.9)
    }

    private var dispatchCardSubtitle: String {
        if isTeamModeEnabled == false {
            return bookingsForFocusDate.isEmpty ? "当前日期暂无排班" : "个人模式下按日期查看全部安排。"
        }
        if let memberName = currentCrewMemberName {
            return bookingsForFocusDate.isEmpty ? "当前日期暂无排班" : "快速回答“\(memberName) 今天拍什么，其他人拍什么”。"
        }
        return bookingsForFocusDate.isEmpty ? "当前日期暂无排班" : "支持摄影师个人与摄影工作室按成员分工查看。"
    }

    private func focusAssignmentCard(_ booking: BookingRecord, isMine: Bool) -> some View {
        let personalText = personalAssignmentText(for: booking)
        let teamText = teamAssignmentText(for: booking)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(SchedulePalette.ink)
                    Text(store.clientName(for: booking))
                        .font(AppTypography.meta)
                        .foregroundStyle(SchedulePalette.secondary)
                }

                Spacer(minLength: 10)

                if isMine {
                    Text("我负责")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentSurface, in: Capsule())
                } else if personalText != nil {
                    Text("同日关联")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentWarmSoft, in: Capsule())
                }
            }

            Text(booking.title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(SchedulePalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let personalText {
                AppInlineNote(systemImage: "person.crop.circle.badge.checkmark", text: personalText, tint: AppTheme.accentWarmDeep)
            } else if let teamText {
                AppInlineNote(systemImage: "person.3.fill", text: teamText)
            }

            Text(booking.venue.isEmpty ? booking.fullAddressText : booking.venue)
                .font(AppTypography.meta)
                .foregroundStyle(SchedulePalette.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isMine ? AppTheme.accentSoft.opacity(0.86) : SchedulePalette.panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((isMine ? AppTheme.accent.opacity(0.22) : SchedulePalette.line.opacity(0.82)), lineWidth: 1)
        }
    }

    private func applyCrewLens(_ name: String?) {
        var updated = store.settings
        updated.currentCrewMemberID = nil
        updated.currentMemberName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.crewLensEnabled = name != nil
        store.updateSettings(updated)
        AppHaptics.selection()
    }

    private func personalAssignmentText(for booking: BookingRecord) -> String? {
        guard let memberName = currentCrewMemberName else { return nil }
        let assignments = store.assignments(for: booking, matching: memberName)
        guard assignments.isEmpty == false else { return nil }
        return assignments.map(\.operationalSummaryText).joined(separator: " / ")
    }

    private func teamAssignmentText(for booking: BookingRecord) -> String? {
        guard isTeamModeEnabled, booking.crewAssignments.isEmpty == false else { return nil }
        return BookingShareTextBuilder.crewAssignmentSummary(for: booking)
    }

    private func responsibilitySummary(for booking: BookingRecord) -> (text: String, isMine: Bool)? {
        if let personalText = personalAssignmentText(for: booking) {
            return (personalText, true)
        }
        if let teamText = teamAssignmentText(for: booking) {
            return (teamText, false)
        }
        return nil
    }

    private var scheduleBoardCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            viewModeSegmentedControl
            periodNavigator
            metaSummaryRow

            if viewMode == .list {
                listFeedContent
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    weekdayHeader

                    Grid(horizontalSpacing: 8, verticalSpacing: 10) {
                        ForEach(Array(calendarRows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(row, id: \.self) { date in
                                    calendarCell(
                                        for: date,
                                        inCurrentMonth: calendar.isDate(date, equalTo: focusDate, toGranularity: .month)
                                    )
                                }
                            }
                        }
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 28, fillColor: SchedulePalette.panel, strokeOpacity: 0.92)
    }

    private var viewModeSegmentedControl: some View {
        HStack(spacing: 6) {
            ForEach(ScheduleViewMode.allCases) { mode in
                Button {
                    guard viewMode != mode else { return }
                    withAnimation(nil) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 15, weight: viewMode == mode ? .semibold : .medium))
                        .foregroundStyle(viewMode == mode ? SchedulePalette.ink : SchedulePalette.secondary.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            Capsule(style: .continuous)
                                .fill(viewMode == mode ? Color.white.opacity(0.72) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        }
    }

    private var periodNavigator: some View {
        HStack(spacing: 12) {
            navigatorButton(symbol: "chevron.left") {
                shiftFocus(by: -1)
                AppHaptics.selection()
            }

            Spacer(minLength: 0)

            Text(periodTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(SchedulePalette.ink)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if scope == .active {
                    Button("今天") {
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            focusDate = .now
                        }
                        AppHaptics.selection()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SchedulePalette.green)
                    .frame(minWidth: 44, minHeight: 40)
                }

                navigatorButton(symbol: "chevron.right") {
                    shiftFocus(by: 1)
                    AppHaptics.selection()
                }
            }
        }
    }

    private var metaSummaryRow: some View {
        HStack(spacing: 12) {
            Text(filterSummary)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(SchedulePalette.muted)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(filteredBookings.count) 个结果")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(SchedulePalette.secondary)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(shortWeekdaySymbols, id: \.self) { item in
                Text(item)
                    .font(AppTypography.meta)
                    .foregroundStyle(SchedulePalette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var todayAgendaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(calendar.isDateInToday(focusDate) ? "今日安排" : "当天安排")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(SchedulePalette.ink)
                }

                Spacer()
            }

            if bookingsForFocusDate.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(scope == .active ? "今天暂无拍摄安排" : "这一天没有归档项目")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SchedulePalette.ink)

                    Text(
                        scope == .active
                        ? "切换视图查看今天、近期与历史档期。"
                        : "切换回主列表，可以继续查看仍在推进中的拍摄安排。"
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SchedulePalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bookingsForFocusDate.enumerated()), id: \.element.id) { index, booking in
                        VStack(spacing: 0) {
                            focusBookingCard(booking)

                            if index < bookingsForFocusDate.count - 1 {
                                Divider()
                                    .overlay(SchedulePalette.line.opacity(0.72))
                                    .padding(.leading, 2)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 28, fillColor: SchedulePalette.panel, strokeOpacity: 0.9)
    }

    private var listFeedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if groupedBookings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(trimmedSearchText.isEmpty ? (scope == .active ? "暂无档期" : "暂无归档档期") : "没有找到相关档期")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SchedulePalette.ink)
                    Text(
                        trimmedSearchText.isEmpty
                        ? (scope == .active ? "新建后会自动出现在这里，方便按日期查看过去、今天与未来安排。" : "已完成或暂不处理的档期会保留在这里。")
                        : "试试换一个关键词，搜索客户、项目名称、地点或备注。"
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SchedulePalette.secondary)
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 22) {
                    ForEach(Array(groupedBookings.enumerated()), id: \.element.date) { _, group in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(AppFormatters.day(group.date))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(SchedulePalette.ink)
                                    Text("\(group.bookings.count) 个项目")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(SchedulePalette.secondary)
                                }
                                Spacer()
                                if conflictDates.contains(group.date) {
                                    Label("有冲突", systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(SchedulePalette.accent)
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(group.bookings.enumerated()), id: \.element.id) { index, booking in
                                    VStack(spacing: 0) {
                                        bookingFeedCard(booking)

                                        if index < group.bookings.count - 1 {
                                            Divider()
                                                .overlay(SchedulePalette.line.opacity(0.72))
                                                .padding(.leading, 2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func headerButton<Fill: ShapeStyle>(
        symbol: String,
        tint: Color,
        fill: Fill,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
    }

    private func dashboardListRow<Content: View>(_ content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func navigatorButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SchedulePalette.ink)
                .frame(width: 40, height: 40)
                .background(SchedulePalette.panelMuted, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func overviewMetricBlock(value: String, title: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(SchedulePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(SchedulePalette.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .center)
    }

    private func calendarCell(for date: Date, inCurrentMonth: Bool) -> some View {
        let day = calendar.component(.day, from: date)
        let startOfDay = calendar.startOfDay(for: date)
        let bookings = bookingsByStartDay[startOfDay, default: []]
        let isSelected = calendar.isDate(date, inSameDayAs: focusDate)
        let isToday = calendar.isDateInToday(date)
        let markerColors = markerColors(for: bookings)
        let density = bookings.count
        let background = calendarCellBackground(
            isSelected: isSelected,
            isToday: isToday,
            isCurrentMonth: inCurrentMonth,
            density: density
        )

        return Button {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                focusDate = date
            }
            AppHaptics.selection()
        } label: {
            VStack(spacing: 8) {
                Text("\(day)")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(calendarCellTextColor(isSelected: isSelected, isCurrentMonth: inCurrentMonth))

                densityIndicator(count: density, colors: markerColors, selected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .frame(height: viewMode == .month ? 60 : 70)
            .background(background)
            .overlay {
                if isToday && isSelected == false {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SchedulePalette.green.opacity(0.42), lineWidth: 1.1)
                }
            }
            .opacity(viewMode == .week ? 1 : (inCurrentMonth ? 1 : 0.38))
        }
        .buttonStyle(.plain)
    }

    private func calendarCellBackground(
        isSelected: Bool,
        isToday: Bool,
        isCurrentMonth: Bool,
        density: Int
    ) -> some View {
        let baseFill: Color
        if isSelected {
            baseFill = colorScheme == .dark ? AppTheme.panelStrong : Color.white.opacity(0.96)
        } else if density >= 3 && isCurrentMonth {
            baseFill = colorScheme == .dark ? AppTheme.panel : Color(uiColor: UIColor(hex: "#F4F7F4"))
        } else {
            baseFill = SchedulePalette.panelSoft
        }

        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(baseFill)
            .shadow(
                color: isSelected ? SchedulePalette.shadow.opacity(0.6) : .clear,
                radius: isSelected ? 10 : 0,
                y: isSelected ? 3 : 0
            )
    }

    private func calendarCellTextColor(isSelected: Bool, isCurrentMonth: Bool) -> Color {
        if isSelected {
            return SchedulePalette.ink
        }
        return isCurrentMonth || viewMode == .week ? SchedulePalette.ink : SchedulePalette.secondary
    }

    private func densityIndicator(count: Int, colors: [Color], selected: Bool) -> some View {
        Group {
            switch count {
            case 0:
                Color.clear
                    .frame(height: 5)
            case 1:
                Circle()
                    .fill(selected ? SchedulePalette.green : (colors.first ?? SchedulePalette.green))
                    .frame(width: 6, height: 6)
            case 2:
                HStack(spacing: 4) {
                    Circle()
                        .fill(selected ? SchedulePalette.green : (colors[safe: 0] ?? SchedulePalette.green))
                    Circle()
                        .fill(selected ? SchedulePalette.green.opacity(0.78) : (colors[safe: 1] ?? SchedulePalette.accent))
                }
                .frame(width: 18, height: 6)
            default:
                Capsule()
                    .fill(selected ? SchedulePalette.green : (colors.first ?? SchedulePalette.green))
                    .frame(width: 18, height: 5)
            }
        }
    }

    private func markerColors(for bookings: [BookingRecord]) -> [Color] {
        bookings.prefix(2).map { booking in
            categoryMarkerColor(for: booking.category)
        }
    }

    private func categoryMarkerColor(for category: ServiceCategory) -> Color {
        switch category {
        case .wedding, .engagement:
            SchedulePalette.accent
        case .corporate, .product, .ecommerce, .food, .space, .commercial, .event, .video, .documentaryFilm:
            SchedulePalette.green
        default:
            SchedulePalette.portrait
        }
    }

    private func focusBookingCard(_ booking: BookingRecord) -> some View {
        let summary = responsibilitySummary(for: booking)

        return NavigationLink(value: ScheduleRoute(bookingID: booking.id)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(store.clientName(for: booking))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(SchedulePalette.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if summary?.isMine == true {
                        Text("我负责")
                            .font(AppTypography.badge)
                            .foregroundStyle(AppTheme.accentWarmDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentSurface, in: Capsule())
                    } else {
                        BookingStatusBadge(status: booking.status)
                    }
                }

                Text(booking.title)
                    .font(AppTypography.body)
                    .foregroundStyle(SchedulePalette.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    infoLine(systemName: booking.category.symbolName, text: booking.category.title)
                    infoLine(systemName: "clock", text: AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                }

                Text(booking.venue.isEmpty ? booking.fullAddressText : booking.venue)
                    .font(AppTypography.meta)
                    .foregroundStyle(SchedulePalette.secondary)
                    .lineLimit(2)

                if let summary {
                    AppInlineNote(
                        systemImage: summary.isMine ? "person.crop.circle.badge.checkmark" : "person.3.fill",
                        text: summary.text,
                        tint: summary.isMine ? AppTheme.accentWarmDeep : AppTheme.secondaryInk
                    )
                }

                HStack(spacing: 10) {
                    BookingStatusBadge(status: booking.status)
                    if booking.crewAssignments.isEmpty == false {
                        Spacer(minLength: 8)
                        Text("\(booking.crewAssignments.count) 人分工")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(SchedulePalette.secondary)
                    }
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func bookingFeedCard(_ booking: BookingRecord) -> some View {
        let summary = responsibilitySummary(for: booking)

        return NavigationLink(value: ScheduleRoute(bookingID: booking.id)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(SchedulePalette.ink)
                        Text(AppFormatters.shortMonthDay(booking.startAt))
                            .font(AppTypography.meta)
                            .foregroundStyle(SchedulePalette.secondary)
                    }

                    Spacer(minLength: 8)

                    if summary?.isMine == true {
                        Text("我负责")
                            .font(AppTypography.badge)
                            .foregroundStyle(AppTheme.accentWarmDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentSurface, in: Capsule())
                    } else {
                        BookingStatusBadge(status: booking.status)
                    }
                }

                Text(store.clientName(for: booking))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(SchedulePalette.ink)
                    .lineLimit(1)

                Text(booking.title)
                    .font(AppTypography.body)
                    .foregroundStyle(SchedulePalette.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Label(booking.venue.isEmpty ? booking.fullAddressText : booking.venue, systemImage: "mappin.and.ellipse")
                        .font(AppTypography.meta)
                        .foregroundStyle(SchedulePalette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let summary {
                        AppInlineNote(
                            systemImage: summary.isMine ? "person.crop.circle.badge.checkmark" : "person.3.fill",
                            text: summary.text,
                            tint: summary.isMine ? AppTheme.accentWarmDeep : AppTheme.secondaryInk
                        )
                    }

                    HStack(spacing: 10) {
                        BookingStatusBadge(status: booking.status)
                        Spacer(minLength: 0)
                        if booking.crewAssignments.isEmpty == false {
                            Text("\(booking.crewAssignments.count) 人分工")
                                .font(AppTypography.meta.weight(.semibold))
                                .foregroundStyle(SchedulePalette.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingBooking = booking
            }
            .tint(AppTheme.accent)

            Button(scope == .active ? "归档" : "恢复", systemImage: scope == .active ? "archivebox" : "arrow.uturn.backward.circle") {
                if scope == .active {
                    store.archiveBooking(booking.id)
                } else {
                    store.restoreBooking(booking.id)
                }
            }
            .tint(scope == .active ? AppTheme.secondaryInk : AppTheme.success)

            Button("删除", systemImage: "trash", role: .destructive) {
                deletingBooking = booking
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if scope == .active && booking.status != .delivered && booking.status != .cancelled {
                Button("完成", systemImage: "checkmark.circle.fill") {
                    var updated = booking
                    updated.status = .delivered
                    store.upsert(booking: updated)
                }
                .tint(AppTheme.success)
            }
        }
        .contextMenu {
            if scope == .active {
                Button("编辑", systemImage: "square.and.pencil") {
                    editingBooking = booking
                }
                Button("归档", systemImage: "archivebox") {
                    store.archiveBooking(booking.id)
                }
            } else {
                Button("恢复到主列表", systemImage: "arrow.uturn.backward.circle") {
                    store.restoreBooking(booking.id)
                }
            }
            Button(role: .destructive) {
                deletingBooking = booking
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func infoLine(systemName: String, text: String) -> some View {
        Label {
            Text(text)
                .lineLimit(2)
        } icon: {
            Image(systemName: systemName)
        }
        .font(AppTypography.meta)
        .foregroundStyle(SchedulePalette.secondary)
    }

    private var periodTitle: String {
        switch viewMode {
        case .month:
            return AppFormatters.monthYear(focusDate)
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: focusDate) else {
                return AppFormatters.shortDate(focusDate)
            }
            let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            return AppFormatters.weekRange(start: weekInterval.start, end: endDate)
        case .list:
            return AppFormatters.monthYear(focusDate)
        }
    }

    private var shortWeekdaySymbols: [String] {
        AppFormatters.reorderedShortWeekdaySymbols(firstWeekday: calendar.firstWeekday)
    }

    private func shiftFocus(by value: Int) {
        switch viewMode {
        case .month, .list:
            if let next = calendar.date(byAdding: .month, value: value, to: focusDate) {
                focusDate = next
            }
        case .week:
            if let next = calendar.date(byAdding: .weekOfYear, value: value, to: focusDate) {
                focusDate = next
            }
        }
    }

    private func matches(filter: ScheduleFilter, booking: BookingRecord) -> Bool {
        switch filter {
        case .all:
            true
        case .active:
            booking.status != .delivered
        case .attention:
            booking.status == .inquiry || booking.status == .tentative || store.outstandingAmount(for: booking) > 0
        case .delivered:
            booking.status == .delivered
        }
    }

    private func matches(keyword: String, booking: BookingRecord) -> Bool {
        let crewTerms = booking.crewAssignments.flatMap {
            [$0.displayName, $0.role.title, $0.taskText, $0.venueText, $0.notesText]
        }

        return AppFormatters.matchesSearch(keyword, terms: [
            booking.title,
            booking.venue,
            booking.city,
            store.clientName(for: booking),
            booking.category.title,
            booking.status.title,
            booking.deliverableText,
            booking.notesText
        ] + crewTerms)
    }
}

private struct ScheduleSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    @Binding var searchText: String
    let bookings: [BookingRecord]
    let scope: ScheduleScope

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmptyQuery: Bool {
        trimmedQuery.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchHeroCard

                    if isEmptyQuery {
                        searchPromptCard
                    } else if bookings.isEmpty {
                        emptyResultCard
                    } else {
                        resultListCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(SchedulePalette.background.ignoresSafeArea())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索客户、项目、地点、成员、备注")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scope == .active ? "搜索主列表" : "搜索归档")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)

            Text(isEmptyQuery ? "输入客户、项目、地点、成员或备注。" : "共找到 \(bookings.count) 个相关档期。")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.78)
    }

    private var searchPromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("开始搜索")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)
            Text("支持搜索客户、项目名称、地点、团队成员与备注。")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }

    private var emptyResultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("没有找到相关档期")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)
            Text("换一个关键词试试，或回到筛选页调整范围和状态。")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }

    private var resultListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(bookings.count) 个结果")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)

            VStack(spacing: 10) {
                ForEach(bookings) { booking in
                    NavigationLink {
                        BookingDetailView(bookingID: booking.id)
                    } label: {
                        searchResultRow(for: booking)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }

    private func searchResultRow(for booking: BookingRecord) -> some View {
        let venueText = booking.venue.isEmpty ? booking.fullAddressText : booking.venue
        let scheduleText = AppFormatters.shortDate(booking.startAt) + " · " + venueText
        let crewSummary = booking.crewAssignments.isEmpty ? nil : BookingShareTextBuilder.crewAssignmentSummary(for: booking)

        return VStack(alignment: .leading, spacing: 8) {
            Text(store.clientName(for: booking))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)

            Text(booking.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)

            Text(scheduleText)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(SchedulePalette.muted)
                .lineLimit(2)

            if let crewSummary {
                Text(crewSummary)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(SchedulePalette.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SchedulePalette.panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SchedulePalette.line.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct ScheduleFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var searchText: String
    @Binding var filter: ScheduleFilter
    @Binding var viewMode: ScheduleViewMode
    @Binding var scope: ScheduleScope

    let summary: String
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    keywordCard
                    pickerCard(title: "查看范围") {
                        Picker("查看范围", selection: $scope) {
                            ForEach(ScheduleScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    pickerCard(title: "状态") {
                        Picker("状态", selection: $filter) {
                            ForEach(ScheduleFilter.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    pickerCard(title: "打开方式") {
                        Picker("打开方式", selection: $viewMode) {
                            ForEach(ScheduleViewMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(SchedulePalette.background.ignoresSafeArea())
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("重置") {
                        onReset()
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前条件")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)
            Text(summary)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }

    private var keywordCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关键词")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)

            TextField("搜索客户、项目、地点、成员、备注", text: $searchText)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(SchedulePalette.panelSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SchedulePalette.line.opacity(0.55), lineWidth: 1)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 24, fillColor: SchedulePalette.panel, strokeOpacity: 0.72)
    }
}

private struct ScheduleTimelineInsightSheet: View {
    @Environment(\.dismiss) private var dismiss

    let focusDate: Date
    let bookings: [BookingRecord]
    let conflictCount: Int

    private let calendar = Calendar.current

    private var todayCount: Int {
        bookings.filter { calendar.isDateInToday($0.startAt) }.count
    }

    private var futureCount: Int {
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return bookings.filter { $0.startAt >= tomorrowStart }.count
    }

    private var pastCount: Int {
        let todayStart = calendar.startOfDay(for: .now)
        return bookings.filter { $0.endAt < todayStart }.count
    }

    private var busyDays: Int {
        Set(bookings.map { calendar.startOfDay(for: $0.startAt) }).count
    }

    private var topCategories: [(name: String, count: Int)] {
        Dictionary(grouping: bookings, by: \.category.title)
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name < rhs.name
                }
                return lhs.count > rhs.count
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppFormatters.monthYear(focusDate))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(SchedulePalette.ink)
                        Text("档期时间概览")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SchedulePalette.secondary)
                    }

                    VStack(spacing: 12) {
                        insightMetric(title: "历史档期", value: "\(pastCount) 场")
                        insightMetric(title: "未来档期", value: "\(futureCount) 场")
                        insightMetric(title: "忙碌日", value: "\(busyDays) 天")
                        insightMetric(title: "今日安排", value: "\(todayCount) 场")
                        insightMetric(title: "冲突日期", value: "\(conflictCount)")
                    }

                    if topCategories.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("项目分布")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(SchedulePalette.ink)

                            ForEach(Array(topCategories.prefix(4).enumerated()), id: \.offset) { _, item in
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(SchedulePalette.ink)
                                    Spacer()
                                    Text("\(item.count) 场")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(SchedulePalette.secondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(SchedulePalette.panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(SchedulePalette.background.ignoresSafeArea())
            .navigationTitle("档期概览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func insightMetric(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SchedulePalette.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SchedulePalette.ink)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(SchedulePalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SchedulePalette.line.opacity(0.9), lineWidth: 1)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
