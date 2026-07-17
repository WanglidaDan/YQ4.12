import SwiftUI

private enum FollowUpFilter: String, CaseIterable, Identifiable {
    case all
    case overdue
    case today
    case upcoming
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .overdue: "逾期"
        case .today: "今天"
        case .upcoming: "待办"
        case .completed: "已完成"
        }
    }
}

private enum FollowUpScope: String, CaseIterable, Identifiable {
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

private struct FollowUpSectionModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let items: [TouchpointRecord]
}

private enum FollowUpRoute: Hashable {
    case booking(UUID)
}

struct FollowUpView: View {
    @Environment(StudioStore.self) private var store

    let onOpenSchedule: () -> Void
    let onOpenClients: () -> Void

    @State private var filter: FollowUpFilter = .all
    @State private var scope: FollowUpScope = .active
    @State private var searchText = ""
    @State private var editingTouchpoint: TouchpointRecord?
    @State private var deletingTouchpoint: TouchpointRecord?
    @State private var showingFilterSheet = false
    @State private var showingNewTouchpoint = false

    private let calendar = Calendar.current

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var snapshot: OverviewSnapshot {
        store.overviewSnapshot
    }

    private var overdue: [TouchpointRecord] {
        filteredBaseItems.filter { $0.isComplete == false && $0.dueAt < .now && calendar.isDateInToday($0.dueAt) == false }
    }

    private var today: [TouchpointRecord] {
        filteredBaseItems.filter { $0.isComplete == false && calendar.isDateInToday($0.dueAt) }
    }

    private var upcoming: [TouchpointRecord] {
        filteredBaseItems.filter { $0.isComplete == false && $0.dueAt >= .now && calendar.isDateInToday($0.dueAt) == false }
    }

    private var completed: [TouchpointRecord] {
        filteredBaseItems.filter(\.isComplete)
    }

    private var filteredBaseItems: [TouchpointRecord] {
        sourceItems
            .filter { matches(searchText: trimmedSearchText, item: $0) }
            .sorted { lhs, rhs in
                if lhs.isComplete == rhs.isComplete {
                    return lhs.dueAt < rhs.dueAt
                }
                return lhs.isComplete == false
            }
    }

    private var sourceItems: [TouchpointRecord] {
        switch scope {
        case .active:
            store.touchpoints.filter { $0.isArchived == false }
        case .archived:
            store.archivedTouchpoints
        }
    }

    private var sections: [FollowUpSectionModel] {
        if scope == .archived {
            let archivedItems = filteredBaseItems.sorted { $0.dueAt > $1.dueAt }
            return archivedItems.isEmpty ? [] : [
                FollowUpSectionModel(
                    id: "archived",
                    title: "已归档",
                    subtitle: "历史记录",
                    items: archivedItems
                )
            ]
        }

        let models: [FollowUpSectionModel]
        switch filter {
        case .all:
            models = [
                FollowUpSectionModel(id: "overdue", title: "已逾期", subtitle: "优先处理", items: overdue),
                FollowUpSectionModel(id: "today", title: "今天要做", subtitle: "今日提醒", items: today),
                FollowUpSectionModel(id: "upcoming", title: "接下来", subtitle: "后续动作", items: upcoming),
                FollowUpSectionModel(id: "completed", title: "已完成", subtitle: "历史触达", items: completed)
            ]
        case .overdue:
            models = [FollowUpSectionModel(id: "overdue", title: "已逾期", subtitle: "优先处理", items: overdue)]
        case .today:
            models = [FollowUpSectionModel(id: "today", title: "今天要做", subtitle: "今日提醒", items: today)]
        case .upcoming:
            models = [FollowUpSectionModel(id: "upcoming", title: "接下来", subtitle: "后续动作", items: upcoming)]
        case .completed:
            models = [FollowUpSectionModel(id: "completed", title: "已完成", subtitle: "历史触达", items: completed)]
        }

        return models.filter { $0.items.isEmpty == false }
    }

    private var filterSummary: String {
        [
            scope.title,
            filter.title
        ].joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            List {
                if scope == .active {
                    Section("待处理事项") {
                        ForEach(snapshot.pendingActions) { item in
                            pendingActionRow(item)
                        }
                    }

                    Section("待回款") {
                        if snapshot.receivableBookings.isEmpty {
                            emptyStateRow(
                                title: "当前没有待回款订单",
                                subtitle: "有待收时会显示在这里。"
                            )
                        } else {
                            receivablesSummaryRow

                            ForEach(snapshot.receivableBookings) { booking in
                                NavigationLink(value: FollowUpRoute.booking(booking.id)) {
                                    receivableRow(booking)
                                }
                            }
                        }
                    }
                }

                if sections.isEmpty {
                    Section {
                        emptyStateRow(
                            title: trimmedSearchText.isEmpty ? (scope == .active ? "暂无跟进事项" : "暂无归档跟进") : "没有搜索到相关内容",
                            subtitle: trimmedSearchText.isEmpty ? (scope == .active ? "从档期或详情页创建提醒。" : "归档任务为空。") : "换个关键词试试。"
                        )
                    }
                } else {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { item in
                                taskRow(item)
                            }
                        } header: {
                            sectionHeader(title: section.title, subtitle: section.subtitle)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("客户跟进")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索客户、项目、跟进内容"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("新建跟进", systemImage: "plus") {
                        showingNewTouchpoint = true
                        AppHaptics.impactMedium()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
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
            .onChange(of: filter) { _, _ in
                AppHaptics.selection()
            }
            .onChange(of: scope) { _, _ in
                AppHaptics.selection()
            }
            .navigationDestination(for: FollowUpRoute.self) { route in
                switch route {
                case let .booking(bookingID):
                    BookingDetailView(bookingID: bookingID)
                }
            }
            .sheet(item: $editingTouchpoint) { item in
                TouchpointEditorView(item: item)
            }
            .sheet(isPresented: $showingNewTouchpoint) {
                TouchpointEditorView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                UnifiedFilterSheet(
                    title: "跟进筛选",
                    summary: filterSummary,
                    onReset: {
                        filter = .all
                        scope = .active
                    }
                ) {
                    Section("列表范围") {
                        Picker("范围", selection: $scope) {
                            ForEach(FollowUpScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("任务筛选") {
                        Picker("筛选", selection: $filter) {
                            ForEach(FollowUpFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .confirmationDialog("确认删除这个跟进？", isPresented: Binding(
                get: { deletingTouchpoint != nil },
                set: { if $0 == false { deletingTouchpoint = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let deletingTouchpoint {
                        store.deleteTouchpoint(deletingTouchpoint.id)
                    }
                    deletingTouchpoint = nil
                }
                Button("取消", role: .cancel) {
                    deletingTouchpoint = nil
                }
            } message: {
                Text("删除后该跟进记录无法恢复。")
            }
        }
    }

    private func pendingActionRow(_ item: OverviewActionItem) -> some View {
        Button {
            AppHaptics.selection()
            switch item.id {
            case .followUp:
                onOpenClients()
            case .confirmBooking, .confirmationSheet, .delivery, .receivable:
                onOpenSchedule()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text(item.valueText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var receivablesSummaryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppFormatters.currency(snapshot.monthlyOutstanding))
                .font(AppTypography.data)
                .foregroundStyle(AppTheme.ink)
            Text("本月待收总额")
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(.vertical, 4)
    }

    private func receivableRow(_ booking: BookingRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Text("\(store.clientName(for: booking)) · \(AppFormatters.shortMonthDay(booking.startAt))")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                PaymentStatusBadge(status: store.paymentStatus(for: booking))
                Text(AppFormatters.currency(store.outstandingAmount(for: booking)))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
            }
        }
        .padding(.vertical, 4)
    }

    private func taskRow(_ item: TouchpointRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text(item.detailsText)
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                }

                Spacer()

                PriorityBadge(priority: item.priority)
            }

            HStack(spacing: 8) {
                tagLabel(title: clientName(for: item), icon: "person.crop.circle")
                if let bookingTitle = bookingTitle(for: item) {
                    tagLabel(title: bookingTitle, icon: "calendar")
                }
            }

            HStack {
                Label(item.channel.title, systemImage: item.channel.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)

                Spacer()

                Text(item.isComplete ? completionText(for: item) : AppFormatters.relativeDueText(item.dueAt, calendar: calendar))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color(for: item))
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingTouchpoint = item
            }
            .tint(AppTheme.accent)

            Button(item.isArchived ? "恢复" : "归档", systemImage: item.isArchived ? "arrow.uturn.backward.circle" : "archivebox") {
                if item.isArchived {
                    store.restoreTouchpoint(item.id)
                } else {
                    store.archiveTouchpoint(item.id)
                }
            }
            .tint(item.isArchived ? AppTheme.success : AppTheme.secondaryInk)

            Button("删除", systemImage: "trash", role: .destructive) {
                deletingTouchpoint = item
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if item.isArchived == false && item.isComplete == false {
                Button("完成", systemImage: "checkmark.circle.fill") {
                    store.markTouchpointComplete(item.id)
                }
                .tint(AppTheme.success)
            } else if item.isArchived == false {
                Button("重开", systemImage: "arrow.counterclockwise") {
                    store.reopenTouchpoint(item.id)
                }
                .tint(AppTheme.info)
            }
        }
        .contextMenu {
            if item.isArchived {
                Button("恢复到主列表", systemImage: "arrow.uturn.backward.circle") {
                    store.restoreTouchpoint(item.id)
                }
            } else {
                Button("归档", systemImage: "archivebox") {
                    store.archiveTouchpoint(item.id)
                }
            }
            Button("编辑", systemImage: "square.and.pencil") {
                editingTouchpoint = item
            }
            Button(role: .destructive) {
                deletingTouchpoint = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        AppSectionHeader(title: title, subtitle: subtitle)
    }

    private func emptyStateRow(title: String, subtitle: String) -> some View {
        AppEmptyState(title: title, subtitle: subtitle, systemImage: "checklist")
    }

    private func tagLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.panelSoft, in: RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous))
    }

    private func color(for item: TouchpointRecord) -> Color {
        if item.isComplete {
            return AppTheme.success
        }
        if item.dueAt < .now && calendar.isDateInToday(item.dueAt) == false {
            return AppTheme.warning
        }
        if calendar.isDateInToday(item.dueAt) {
            return AppTheme.accentWarmDeep
        }
        return AppTheme.secondaryInk
    }

    private func completionText(for item: TouchpointRecord) -> String {
        guard let completedAt = item.completedAt else { return "已完成" }
        return "完成于 \(AppFormatters.shortDate(completedAt))"
    }

    private func clientName(for item: TouchpointRecord) -> String {
        guard let clientID = item.clientID, let client = store.client(id: clientID) else {
            return "未绑定客户"
        }
        return client.name
    }

    private func bookingTitle(for item: TouchpointRecord) -> String? {
        guard let bookingID = item.bookingID, let booking = store.booking(id: bookingID) else {
            return nil
        }
        return booking.title
    }

    private func matches(searchText: String, item: TouchpointRecord) -> Bool {
        AppFormatters.matchesSearch(searchText, terms: [
            item.title,
            item.detailsText,
            clientName(for: item),
            bookingTitle(for: item) ?? "",
            item.channel.title,
            item.priority.title
        ])
    }
}
