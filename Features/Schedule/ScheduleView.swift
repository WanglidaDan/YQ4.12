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
        case .receivable: "待收"
        case .delivery: "交付"
        case .conflict: "冲突"
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
    @State private var showingCreateBookingSheet = false
    @State private var createBookingStartDate: Date?
    @State private var showingSearchSheet = false
    @State private var toastMessage: String?

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

    private var monthlyBookings: [BookingRecord] {
        let base = scope == .active ? store.activeBookings : store.archivedBookings
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        return base.filter { booking in
            monthInterval.contains(booking.startAt) && booking.status != .cancelled
        }
    }

    private var monthlyRevenue: Double {
        monthlyBookings.reduce(0) { $0 + $1.fee }
    }

    private var monthlyOutstanding: Double {
        monthlyBookings.reduce(0) { $0 + store.outstandingAmount(for: $1) }
    }

    private var isPristineSchedule: Bool {
        sourceBookings.isEmpty && filter == .all && trimmedSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBar

                        if isPristineSchedule {
                            scheduleStartState
                        } else {
                            summaryStrip
                            filterStrip
                            modeStrip

                            if viewMode == .list {
                                listSection
                            } else {
                                calendarSection
                                focusDateSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }

                addBookingButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)

                if let toastMessage {
                    AppToast(message: toastMessage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 88)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(for: ScheduleRoute.self) { route in
                BookingDetailView(bookingID: route.bookingID)
            }
            .sheet(item: $editingBooking) { booking in
                BookingEditorView(booking: booking) { savedBooking in
                    showSavedToast(for: savedBooking)
                }
            }
            .sheet(isPresented: $showingCreateBookingSheet) {
                BookingEditorView(initialStartAt: createBookingStartDate) { savedBooking in
                    showSavedToast(for: savedBooking)
                }
            }
            .sheet(isPresented: $showingSearchSheet) {
                ScheduleSearchSheet(
                    searchText: $searchText,
                    bookings: filteredBookings,
                    clientName: { store.clientName(for: $0) }
                )
                .presentationDetents([.medium, .large])
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerBar: some View {
        AppPageHeader(title: "档期", subtitle: monthTitle) {
            HStack(spacing: 10) {
                AppCircleIconButton(systemImage: "magnifyingglass", accessibilityLabel: "搜索档期") {
                    showingSearchSheet = true
                    AppHaptics.tapLight()
                }

                Menu {
                    Picker("范围", selection: $scope) {
                        ForEach(ScheduleScope.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(AppTypography.icon)
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.panelStrong, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("筛选档期范围")
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryItem(title: "成交", value: AppFormatters.currency(monthlyRevenue))
            summaryDivider
            summaryItem(title: "待收", value: AppFormatters.currency(monthlyOutstanding))
            summaryDivider
            summaryItem(title: "今日", value: "\(todayCount)")
            summaryDivider
            summaryItem(title: "未来", value: "\(upcomingCount)")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(AppTypography.rowValue)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
            Text(title)
                .font(AppTypography.small)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(AppTheme.line.opacity(0.68))
            .frame(width: 1, height: 32)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(ScheduleFilter.allCases) { item in
                    Button {
                        apply(filter: item)
                    } label: {
                        VStack(spacing: 7) {
                            Text(item.title)
                                .font(AppTypography.rowValue)
                                .foregroundStyle(filter == item ? AppTheme.accent : AppTheme.secondaryInk)
                            Rectangle()
                                .fill(filter == item ? AppTheme.accent : .clear)
                                .frame(height: 3)
                                .clipShape(Capsule())
                        }
                        .frame(minWidth: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var modeStrip: some View {
        HStack(spacing: 22) {
            ForEach(ScheduleViewMode.allCases) { mode in
                Button {
                    viewMode = mode
                    AppHaptics.selection()
                } label: {
                    VStack(spacing: 7) {
                        Text(mode.title)
                            .font(AppTypography.rowValue)
                            .foregroundStyle(viewMode == mode ? AppTheme.accent : AppTheme.secondaryInk)
                        Rectangle()
                            .fill(viewMode == mode ? AppTheme.accent : .clear)
                            .frame(height: 3)
                            .clipShape(Capsule())
                    }
                    .frame(minWidth: 42)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var scheduleStartState: some View {
        VStack(spacing: 16) {
            Text(scope == .active ? "暂无档期" : "暂无归档")
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.ink)
            if scope == .active {
                Button {
                    createBooking(on: focusDate)
                } label: {
                    Text("新建档期")
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                periodButton("chevron.left") { shiftFocus(by: -1) }
                Spacer()
                Text(monthTitle)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                periodButton("chevron.right") { shiftFocus(by: 1) }
            }

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
        .padding(18)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(AppFormatters.reorderedShortWeekdaySymbols(firstWeekday: calendar.firstWeekday), id: \.self) { symbol in
                Text(symbol)
                    .font(AppTypography.small)
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
                    .font(isSelected ? AppTypography.rowValue : AppTypography.meta)
                    .foregroundStyle(isSelected ? .white : (isCurrentMonth ? AppTheme.ink : AppTheme.secondaryInk.opacity(0.55)))

                HStack(spacing: 3) {
                    if bookings.isEmpty {
                        Circle().fill(Color.clear).frame(width: 5, height: 5)
                    } else {
                        ForEach(0..<min(bookings.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? .white.opacity(0.9) : AppTheme.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSelected ? AppTheme.accent : (isToday ? AppTheme.accent.opacity(0.08) : Color.clear), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hasConflict ? AppTheme.accent.opacity(0.7) : AppTheme.line.opacity(0.34), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var focusDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppFormatters.day(focusDate))
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button("今天") {
                    focusDate = .now
                    AppHaptics.selection()
                }
                .font(AppTypography.rowValue)
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
            }

            if bookingsForFocusDate.isEmpty {
                compactEmptyState
            } else {
                bookingList(bookingsForFocusDate)
            }
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if groupedBookings.isEmpty {
                compactEmptyState
            } else {
                ForEach(Array(groupedBookings.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppFormatters.day(group.date))
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                        bookingList(group.bookings)
                    }
                }
            }
        }
    }

    private func bookingList(_ bookings: [BookingRecord]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(bookings.enumerated()), id: \.element.id) { item in
                scheduleRow(item.element)
                if item.offset < bookings.count - 1 {
                    rowDivider
                }
            }
        }
        .padding(.vertical, 4)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private var compactEmptyState: some View {
        VStack(spacing: 12) {
            Text("暂无档期")
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.ink)
            Button {
                createBooking(on: focusDate)
            } label: {
                Text("新建档期")
                    .font(AppTypography.rowValue)
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private func scheduleRow(_ booking: BookingRecord) -> some View {
        NavigationLink(value: ScheduleRoute(bookingID: booking.id)) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFormatters.time(booking.startAt))
                        .font(AppTypography.rowValue)
                        .foregroundStyle(AppTheme.ink)
                    Text(AppFormatters.time(booking.endAt))
                        .font(AppTypography.small)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(booking.title)
                            .font(AppTypography.rowTitle)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                        if shouldShowStatus(for: booking) {
                            Text(booking.status.title)
                                .font(AppTypography.badge)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    Text(rowSubtitle(for: booking))
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)

                    if booking.fullAddressText.isEmpty == false {
                        Text(booking.fullAddressText)
                            .font(AppTypography.small)
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppTheme.mutedInk)
                    .padding(.top, 5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑") { editingBooking = booking }
        }
    }

    private func rowSubtitle(for booking: BookingRecord) -> String {
        let client = store.clientName(for: booking)
        let place = booking.venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if place.isEmpty { return client }
        return "\(client) · \(place)"
    }

    private func shouldShowStatus(for booking: BookingRecord) -> Bool {
        booking.status == .cancelled || booking.status == .editing
    }

    private var addBookingButton: some View {
        Button {
            createBooking(on: .now)
        } label: {
            Label("新建档期", systemImage: "plus")
                .font(AppTypography.rowTitle)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.deepShadow.opacity(0.28), radius: 16, x: 0, y: 9)
        }
        .buttonStyle(.plain)
    }

    private func periodButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 34, height: 34)
                .background(AppTheme.panelSoft, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
            .padding(.leading, 80)
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

    private func showSavedToast(for booking: BookingRecord) {
        withAnimation(.snappy(duration: 0.2)) {
            toastMessage = "已保存：\(booking.title)"
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy(duration: 0.2)) {
                if toastMessage == "已保存：\(booking.title)" {
                    toastMessage = nil
                }
            }
        }
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
            store.clientName(for: booking)
        ])
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
                TextField("搜索", text: $searchText)
                    .font(AppTypography.rowValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
                    }
                    .padding(.horizontal, 18)

                if bookings.isEmpty {
                    ContentUnavailableView("暂无结果", systemImage: "magnifyingglass")
                        .frame(maxHeight: .infinity)
                } else {
                    List(bookings.prefix(30)) { booking in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(booking.title)
                                .font(AppTypography.rowTitle)
                            Text("\(clientName(booking)) · \(AppFormatters.fullDate(booking.startAt))")
                                .font(AppTypography.meta)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
        }
    }
}
