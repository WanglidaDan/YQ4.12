import SwiftUI
import UIKit

private enum ScheduleFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case tomorrow
    case upcoming
    case week
    case receivable
    case delivery
    case conflict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .today: "今天"
        case .tomorrow: "明天"
        case .upcoming: "未来"
        case .week: "本周"
        case .receivable: "待回款"
        case .delivery: "待交付"
        case .conflict: "有冲突"
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
        case .active: "进行中"
        case .archived: "归档"
        }
    }
}

private struct ScheduleRoute: Hashable {
    let bookingID: UUID
}

private typealias BookingDayGroup = (date: Date, bookings: [BookingRecord])

struct ScheduleView: View {
    @Environment(StudioStore.self) private var store

    @State private var filter: ScheduleFilter = .all
    @State private var viewMode: ScheduleViewMode = .month
    @State private var scope: ScheduleScope = .active
    @State private var searchText = ""
    @State private var focusDate = Date()
    @State private var editingBooking: BookingRecord?
    @State private var deletingBooking: BookingRecord?
    @State private var showingCreateBookingSheet = false
    @State private var createBookingStartDate: Date?
    @State private var showingSearchSheet = false

    private let calendar = Calendar.current

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceBookings: [BookingRecord] {
        let source = scope == .active ? store.activeBookings : store.archivedBookings
        return source.sorted { $0.startAt < $1.startAt }
    }

    private var filteredBookings: [BookingRecord] {
        sourceBookings.filter { booking in
            matchesFilter(booking) && matchesSearch(booking)
        }
    }

    private var bookingsForFocusDate: [BookingRecord] {
        filteredBookings
            .filter { calendar.isDate($0.startAt, inSameDayAs: focusDate) }
            .sorted { $0.startAt < $1.startAt }
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

    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: focusDate) else { return [] }
        return stride(from: weekInterval.start, to: weekInterval.end, by: 60 * 60 * 24).map { $0 }
    }

    private var visibleDates: [Date] {
        viewMode == .month ? monthDates : weekDates
    }

    private var calendarRows: [[Date]] {
        stride(from: 0, to: visibleDates.count, by: 7).map { start in
            Array(visibleDates[start..<min(start + 7, visibleDates.count)])
        }
    }

    private var bookingsByDay: [Date: [BookingRecord]] {
        Dictionary(grouping: filteredBookings) { calendar.startOfDay(for: $0.startAt) }
    }

    private var sourceConflictDates: Set<Date> {
        let grouped = Dictionary(grouping: sourceBookings) { calendar.startOfDay(for: $0.startAt) }
        return Set(grouped.compactMap { day, bookings in bookings.count > 1 ? day : nil })
    }

    private var conflictDates: Set<Date> {
        Set(bookingsByDay.compactMap { day, bookings in bookings.count > 1 ? day : nil })
    }

    private var groupedBookings: [BookingDayGroup] {
        bookingsByDay
            .map { (date: $0.key, bookings: $0.value.sorted { $0.startAt < $1.startAt }) }
            .sorted { $0.date < $1.date }
    }

    private var monthTitle: String {
        if viewMode == .week,
           let start = weekDates.first,
           let end = weekDates.last {
            return AppFormatters.weekRange(start: start, end: end)
        }
        return AppFormatters.monthYear(focusDate)
    }

    private var todayCount: Int {
        sourceBookings.filter { calendar.isDateInToday($0.startAt) }.count
    }

    private var upcomingCount: Int {
        let today = calendar.startOfDay(for: .now)
        return sourceBookings.filter { $0.startAt >= today && $0.status != .cancelled }.count
    }

    private var receivableCount: Int {
        sourceBookings.filter { store.outstandingAmount(for: $0) > 0 && $0.status != .cancelled }.count
    }

    private var deliveryCount: Int {
        sourceBookings.filter { $0.status == .editing }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBar
                        overviewStrip
                        quickFilterRow
                        calendarSection
                        focusDateSection

                        if viewMode == .list {
                            listSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }

                addBookingButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
            .navigationDestination(for: ScheduleRoute.self) { route in
                BookingDetailView(bookingID: route.bookingID)
            }
            .sheet(item: $editingBooking) { booking in
                BookingEditorView(booking: booking)
            }
            .sheet(isPresented: $showingCreateBookingSheet) {
                BookingEditorView(initialStartAt: createBookingStartDate)
            }
            .sheet(isPresented: $showingSearchSheet) {
                ScheduleSearchSheet(
                    searchText: $searchText,
                    bookings: filteredBookings,
                    clientName: { store.clientName(for: $0) }
                )
                .presentationDetents([.medium, .large])
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var pageBackground: some View {
        AppTheme.backgroundGradient
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("档期")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text(monthTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Spacer()

            Button {
                showingSearchSheet = true
                AppHaptics.tapLight()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索档期")

            Menu {
                Picker("范围", selection: $scope) {
                    ForEach(ScheduleScope.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Picker("视图", selection: $viewMode) {
                    ForEach(ScheduleViewMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("筛选档期")
        }
    }

    private var overviewStrip: some View {
        HStack(spacing: 0) {
            compactMetric("今日", value: todayCount, filter: .today)
            Divider().frame(height: 30)
            compactMetric("未来", value: upcomingCount, filter: .upcoming)
            Divider().frame(height: 30)
            compactMetric("待收", value: receivableCount, filter: .receivable)
            Divider().frame(height: 30)
            compactMetric("待交付", value: deliveryCount, filter: .delivery)
        }
        .padding(.vertical, 16)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private func compactMetric(_ title: String, value: Int, filter targetFilter: ScheduleFilter) -> some View {
        Button {
            apply(filter: targetFilter)
        } label: {
            VStack(spacing: 5) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(filter == targetFilter ? AppTheme.accent : AppTheme.ink)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(filter == targetFilter ? AppTheme.accent : AppTheme.secondaryInk)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)：\(value)")
    }

    private var quickFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ScheduleFilter.allCases) { item in
                    Button {
                        apply(filter: item)
                    } label: {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(filter == item ? AppTheme.panelStrong : AppTheme.ink)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(filter == item ? AppTheme.accent : AppTheme.panel, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                periodButton("chevron.left") { shiftFocus(by: -1) }
                Spacer()
                viewModeControl
                Spacer()
                periodButton("chevron.right") { shiftFocus(by: 1) }
            }

            if viewMode == .list {
                Text("列表模式下按日期聚合所有匹配档期。")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryInk)
            } else {
                weekdayHeader

                Grid(horizontalSpacing: 8, verticalSpacing: 10) {
                    ForEach(Array(calendarRows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(row, id: \.self) { date in
                                calendarCell(date)
                            }
                        }
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private var viewModeControl: some View {
        HStack(spacing: 5) {
            ForEach(ScheduleViewMode.allCases) { mode in
                Button {
                    viewMode = mode
                    AppHaptics.selection()
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewMode == mode ? AppTheme.ink : AppTheme.secondaryInk)
                        .frame(width: 42, height: 30)
                        .background(viewMode == mode ? AppTheme.panelStrong : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.panelSoft, in: Capsule())
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(AppFormatters.reorderedShortWeekdaySymbols(firstWeekday: calendar.firstWeekday), id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let bookings = bookingsByDay[day, default: []]
        let isSelected = calendar.isDate(date, inSameDayAs: focusDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: focusDate, toGranularity: .month)
        let hasConflict = conflictDates.contains(day)

        return Button {
            focusDate = date
            AppHaptics.selection()
        } label: {
            VStack(spacing: 7) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? AppTheme.panelStrong : (isCurrentMonth ? AppTheme.ink : AppTheme.secondaryInk.opacity(0.55)))

                HStack(spacing: 3) {
                    if bookings.isEmpty {
                        Circle().fill(Color.clear).frame(width: 5, height: 5)
                    } else {
                        ForEach(0..<min(bookings.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? AppTheme.panelStrong.opacity(0.9) : (hasConflict ? AppTheme.warning : AppTheme.accent))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accent : (isToday ? AppTheme.accent.opacity(0.10) : AppTheme.panelSoft))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hasConflict ? AppTheme.warning.opacity(0.7) : AppTheme.line.opacity(0.34), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var focusDateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFormatters.day(focusDate))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(bookingsForFocusDate.isEmpty ? "这一天暂无档期" : "\(bookingsForFocusDate.count) 个安排")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Button("今天") {
                    focusDate = .now
                    AppHaptics.selection()
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.plain)
            }

            if bookingsForFocusDate.isEmpty {
                focusDateEmptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(bookingsForFocusDate) { booking in
                        scheduleRow(booking, compact: false)
                    }
                }
            }
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("全部档期")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            if groupedBookings.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(groupedBookings.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppFormatters.day(group.date))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(group.bookings) { booking in
                                scheduleRow(booking, compact: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("没有匹配的档期")
                .font(.system(size: 16, weight: .semibold))
            Text("可以新建档期，或切换筛选条件查看。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private var focusDateEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("这天还空着")
                .font(.system(size: 16, weight: .semibold))
            Text("可以先占住时间，后面再补客户和报价。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                createBooking(on: focusDate)
            } label: {
                Label("新建这天的档期", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.panelStrong)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private func scheduleRow(_ booking: BookingRecord, compact: Bool) -> some View {
        NavigationLink(value: ScheduleRoute(bookingID: booking.id)) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text(AppFormatters.time(booking.startAt))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(AppFormatters.time(booking.endAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 46)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(booking.title)
                            .font(.system(size: compact ? 16 : 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        Text(booking.status.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                    }

                    Text(store.clientName(for: booking))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    if compact == false {
                        HStack(spacing: 10) {
                            Label(booking.category.title, systemImage: booking.category.symbolName)
                            if booking.fullAddressText.isEmpty == false {
                                Label(booking.fullAddressText, systemImage: "mappin.and.ellipse")
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    if booking.crewAssignments.isEmpty == false {
                        Text(crewSummary(for: booking))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑") { editingBooking = booking }
            Button("删除", role: .destructive) { deletingBooking = booking }
        }
    }

    private var addBookingButton: some View {
        Button {
            createBooking(on: .now)
        } label: {
            Label("新建档期", systemImage: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.panelStrong)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.deepShadow.opacity(0.6), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func periodButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func shiftFocus(by value: Int) {
        let component: Calendar.Component = viewMode == .week ? .weekOfYear : .month
        focusDate = calendar.date(byAdding: component, value: value, to: focusDate) ?? focusDate
        AppHaptics.selection()
    }

    private func createBooking(on date: Date) {
        createBookingStartDate = date
        showingCreateBookingSheet = true
        AppHaptics.impactMedium()
    }

    private func matchesFilter(_ booking: BookingRecord) -> Bool {
        switch filter {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(booking.startAt)
        case .tomorrow:
            return calendar.isDateInTomorrow(booking.startAt)
        case .week:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return true }
            return week.contains(booking.startAt)
        case .upcoming:
            let today = calendar.startOfDay(for: .now)
            return booking.startAt >= today && booking.status != .cancelled
        case .receivable:
            return store.outstandingAmount(for: booking) > 0 && booking.status != .cancelled
        case .delivery:
            return booking.status == .editing
        case .conflict:
            let day = calendar.startOfDay(for: booking.startAt)
            return sourceConflictDates.contains(day)
        }
    }

    private func matchesSearch(_ booking: BookingRecord) -> Bool {
        guard trimmedSearchText.isEmpty == false else { return true }
        return AppFormatters.matchesSearch(trimmedSearchText, terms: [
            booking.title,
            booking.category.title,
            booking.status.title,
            booking.venue,
            booking.city,
            booking.addressText,
            store.clientName(for: booking),
            crewSummary(for: booking)
        ])
    }

    private func crewSummary(for booking: BookingRecord) -> String {
        BookingCrewAssignment.normalized(booking.crewAssignments)
            .map { "\($0.displayName) · \($0.role.title)" }
            .joined(separator: " / ")
    }

    private func apply(filter targetFilter: ScheduleFilter) {
        withAnimation(.snappy(duration: 0.18)) {
            filter = targetFilter
            switch targetFilter {
            case .today:
                focusDate = .now
            case .tomorrow:
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) {
                    focusDate = tomorrow
                }
            case .upcoming:
                if let nextBooking = sourceBookings.first(where: { $0.startAt >= calendar.startOfDay(for: .now) && $0.status != .cancelled }) {
                    focusDate = nextBooking.startAt
                } else {
                    focusDate = .now
                }
            case .all, .week, .receivable, .delivery, .conflict:
                break
            }
        }
        AppHaptics.selection()
    }
}

private struct ScheduleSearchSheet: View {
    @Binding var searchText: String
    let bookings: [BookingRecord]
    let clientName: (BookingRecord) -> String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("搜索客户、地点、类型、标题", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 18)

                if bookings.isEmpty {
                    ContentUnavailableView("暂无结果", systemImage: "magnifyingglass", description: Text("换个关键词试试。"))
                        .frame(maxHeight: .infinity)
                } else {
                    List(bookings.prefix(30)) { booking in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(booking.title)
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(clientName(booking)) · \(AppFormatters.fullDate(booking.startAt))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索档期")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
