import SwiftUI

private enum ClientFilter: String, CaseIterable, Identifiable {
    case all
    case signature
    case followUp
    case retained

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .signature: "高价值"
        case .followUp: "待经营"
        case .retained: "长期"
        }
    }
}

private enum ClientSort: String, CaseIterable, Identifiable {
    case latest
    case value
    case followUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest: "最近新增"
        case .value: "累计价值"
        case .followUp: "跟进优先"
        }
    }
}

private enum ClientScope: String, CaseIterable, Identifiable {
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

private struct ClientRoute: Hashable {
    let clientID: UUID
}

struct ClientsView: View {
    @Environment(StudioStore.self) private var store

    @State private var filter: ClientFilter = .all
    @State private var sort: ClientSort = .followUp
    @State private var scope: ClientScope = .active
    @State private var searchText = ""
    @State private var editingClient: ClientRecord?
    @State private var deletingClient: ClientRecord?
    @State private var deletionResultMessage: String?
    @State private var showingFilterSheet = false
    @State private var showingSearchSheet = false
    @State private var businessCenterRoute: BusinessCenterRoute?

    private let calendar = Calendar.current

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var totalLifetimeValue: Double {
        visibleBookings.reduce(0) { $0 + $1.fee }
    }

    private var followUpClientCount: Int {
        sourceClients.filter(clientNeedsAttention).count
    }

    private var filteredClients: [ClientRecord] {
        sourceClients
            .filter { matches(filter: filter, client: $0) }
            .filter { matches(searchText: trimmedSearchText, client: $0) }
            .sorted(by: compareClients)
    }

    private var featuredClients: [ClientRecord] {
        guard scope == .active else { return [] }
        return Array(filteredClients.filter { clientNeedsAttention($0) || $0.tier == .signature }.prefix(3))
    }

    private var sourceClients: [ClientRecord] {
        switch scope {
        case .active:
            store.activeClients
        case .archived:
            store.archivedClients
        }
    }

    private var visibleBookings: [BookingRecord] {
        switch scope {
        case .active:
            store.activeBookings
        case .archived:
            store.archivedBookings
        }
    }

    private var filterSummary: String {
        [
            "范围：\(scope.title)",
            "筛选：\(filter.title)",
            "排序：\(sort.title)"
        ].joined(separator: " · ")
    }

    private var quickFilterSummary: String {
        switch filter {
        case .all:
            "当前查看全部客户"
        case .signature:
            "当前只看高价值客户"
        case .followUp:
            "当前只看待跟进客户"
        case .retained:
            "当前只看长期客户"
        }
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "客户") {
                header
                quickToolsCard

                if featuredClients.isEmpty == false {
                    clientsBlock(
                        title: "优先关注",
                        subtitle: "高价值、临近跟进与待回款客户"
                    ) {
                        ForEach(featuredClients) { client in
                            clientRow(client)
                        }
                    }
                }

                clientsBlock(
                    title: scope == .active ? "客户列表" : "归档客户",
                    subtitle: filteredClients.isEmpty ? "当前没有符合条件的客户" : "共 \(filteredClients.count) 位"
                ) {
                    if filteredClients.isEmpty {
                        emptyStateRow(
                            title: trimmedSearchText.isEmpty ? (scope == .active ? "还没有客户数据" : "还没有归档客户") : "没有找到相关客户",
                            subtitle: trimmedSearchText.isEmpty ? (scope == .active ? "从工作台新建客户后，这里会自动形成经营清单与优先级。" : "已归档客户会集中沉淀在这里，方便恢复和回看历史合作。") : "试试搜索客户名、城市、来源渠道或手机号。"
                        )
                    } else {
                        ForEach(filteredClients) { client in
                            clientRow(client)
                        }
                    }
                }
            }
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
            .navigationDestination(for: ClientRoute.self) { route in
                ClientDetailView(clientID: route.clientID)
            }
            .sheet(item: $editingClient) { client in
                ClientEditorView(client: client)
            }
            .sheet(item: $businessCenterRoute) { route in
                BusinessCenterView(
                    initialMode: route.mode,
                    bookingID: route.bookingID,
                    clientID: route.clientID
                )
                .environment(store)
            }
            .sheet(isPresented: $showingSearchSheet) {
                ClientSearchSheet(
                    searchText: $searchText,
                    clients: filteredClients,
                    scope: scope
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                UnifiedFilterSheet(
                    title: "客户筛选",
                    summary: filterSummary,
                    onReset: {
                        filter = .all
                        sort = .followUp
                        scope = .active
                    }
                ) {
                    Section("列表范围") {
                        Picker("范围", selection: $scope) {
                            ForEach(ClientScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("客户筛选") {
                        Picker("筛选", selection: $filter) {
                            ForEach(ClientFilter.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("排序方式") {
                        Picker("排序", selection: $sort) {
                            ForEach(ClientSort.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }
                }
            }
            .onChange(of: scope) { _, _ in
                AppHaptics.selection()
            }
            .confirmationDialog("确认删除这个客户？", isPresented: Binding(
                get: { deletingClient != nil },
                set: { if $0 == false { deletingClient = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let deletingClient {
                        let outcome = store.deleteClient(deletingClient.id)
                        if outcome == .archivedToPreserveHistory {
                            deletionResultMessage = "该客户已自动转为归档，以保留历史订单和跟进关联。"
                        }
                    }
                    deletingClient = nil
                }
                Button("取消", role: .cancel) {
                    deletingClient = nil
                }
            } message: {
                Text("若该客户已经关联订单或跟进，为避免破坏历史经营数据，系统会自动改为归档而不是直接删除。")
            }
            .alert("客户已归档", isPresented: Binding(
                get: { deletionResultMessage != nil },
                set: { if $0 == false { deletionResultMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(deletionResultMessage ?? "")
            }
        }
    }

    private var header: some View {
        GlassCard(title: scope == .active ? "客户经营总览" : "客户归档", subtitle: filterSummary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(sourceClients.count)")
                            .font(AppTypography.data)
                            .foregroundStyle(AppTheme.ink)
                        Text("客户总数")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(AppFormatters.currency(totalLifetimeValue))
                            .font(AppTypography.dataCompact)
                            .foregroundStyle(AppTheme.accentWarmDeep)
                        Text("累计签约额")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }

                VStack(spacing: 0) {
                    metricLine(title: "签名客户", value: "\(sourceClients.filter { $0.tier == .signature }.count)")
                    sectionDivider
                    metricLine(title: "待经营", value: "\(followUpClientCount)")
                    sectionDivider
                    metricLine(title: "长期客户", value: "\(sourceClients.filter { $0.stage == .retained }.count)")
                }

                Picker("范围", selection: $scope) {
                    ForEach(ClientScope.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var quickToolsCard: some View {
        GlassCard(title: "工作区工具", subtitle: quickFilterSummary) {
            HStack(spacing: 10) {
                Button {
                    AppHaptics.tapLight()
                    showingSearchSheet = true
                } label: {
                    Label("搜索客户", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button {
                    AppHaptics.tapLight()
                    showingFilterSheet = true
                } label: {
                    Label("筛选排序", systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            if scope == .active {
                Button {
                    businessCenterRoute = BusinessCenterRoute(mode: .workflow, bookingID: nil, clientID: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.accent.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("打开经营中心")
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                            Text("合同、资料、协作与报表集中处理")
                                .font(AppTypography.meta)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .appCardSurface(fillColor: AppTheme.panelStrong)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func clientsBlock<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(title: title, subtitle: subtitle) {
            LazyVStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
    }

    private func clientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(AppTheme.accentSurface)
                            .frame(width: 54, height: 54)
                        Text(client.initials)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.accentDeep)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(client.name)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                                tierLabel(for: client.tier)
                            }

                            Spacer(minLength: 12)

                            Image(systemName: "arrow.up.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            LeadStageBadge(stage: client.stage)
                            Text(clientMetaText(for: client))
                                .font(AppTypography.meta.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            if scope == .active && clientNeedsAttention(client) {
                                attentionBadge
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if client.notesText.isEmpty == false {
                    Text(client.notesText)
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    dualValueLine(
                        leadingTitle: "累计",
                        leadingValue: AppFormatters.currency(lifetimeValue(for: client.id)),
                        trailingTitle: "待回款",
                        trailingValue: AppFormatters.currency(outstandingValue(for: client.id))
                    )

                    Divider()
                        .overlay(AppTheme.line.opacity(0.55))

                    detailLine(title: "下次跟进", value: nextContactText(for: client))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .appCardSurface(fillColor: AppTheme.panelStrong)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            .tint(AppTheme.accent)

            Button(scope == .active ? "归档" : "恢复", systemImage: scope == .active ? "archivebox" : "arrow.uturn.backward.circle") {
                if scope == .active {
                    store.archiveClient(client.id)
                } else {
                    store.restoreClient(client.id)
                }
            }
            .tint(scope == .active ? AppTheme.secondaryInk : AppTheme.success)

            Button("删除", systemImage: "trash", role: .destructive) {
                deletingClient = client
            }
        }
        .contextMenu {
            if scope == .active {
                Button("编辑", systemImage: "square.and.pencil") {
                    editingClient = client
                }
                Button("归档", systemImage: "archivebox") {
                    store.archiveClient(client.id)
                }
            } else {
                Button("恢复到主列表", systemImage: "arrow.uturn.backward.circle") {
                    store.restoreClient(client.id)
                }
            }
            Button(role: .destructive) {
                deletingClient = client
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.9))
            .padding(.vertical, 12)
    }

    private func metricLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer()
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private var attentionBadge: some View {
        Text("需关注")
            .font(AppTypography.badge)
            .foregroundStyle(AppTheme.warning)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.accentWarmSoft, in: RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous))
    }

    private func tierLabel(for tier: ClientTier) -> some View {
        Label(tier.title, systemImage: tierSymbol(for: tier))
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.mutedInk)
    }

    private func dualValueLine(leadingTitle: String, leadingValue: String, trailingTitle: String, trailingValue: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            valueBlock(title: leadingTitle, value: leadingValue)
            valueBlock(title: trailingTitle, value: trailingValue)
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer()
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
        }
    }

    private func valueBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clientMetaText(for client: ClientRecord) -> String {
        let parts = [client.city, client.sourceChannel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? "待补充城市与来源" : parts.joined(separator: " · ")
    }

    private func matches(filter: ClientFilter, client: ClientRecord) -> Bool {
        switch filter {
        case .all:
            true
        case .signature:
            client.tier == .signature
        case .followUp:
            clientNeedsAttention(client)
        case .retained:
            client.stage == .retained
        }
    }

    private func matches(searchText: String, client: ClientRecord) -> Bool {
        AppFormatters.matchesSearch(searchText, terms: [
            client.name,
            client.city,
            client.sourceChannel,
            client.phoneNumber,
            client.notesText,
            client.stage.title,
            client.tier.title
        ])
    }

    private func compareClients(lhs: ClientRecord, rhs: ClientRecord) -> Bool {
        switch sort {
        case .latest:
            return lhs.createdAt > rhs.createdAt
        case .value:
            return lifetimeValue(for: lhs.id) > lifetimeValue(for: rhs.id)
        case .followUp:
            let lhsDate = nextTouchpoint(for: lhs.id)?.dueAt ?? lhs.nextContactAt ?? .distantFuture
            let rhsDate = nextTouchpoint(for: rhs.id)?.dueAt ?? rhs.nextContactAt ?? .distantFuture
            if lhsDate == rhsDate {
                return lifetimeValue(for: lhs.id) > lifetimeValue(for: rhs.id)
            }
            return lhsDate < rhsDate
        }
    }

    private func clientNeedsAttention(_ client: ClientRecord) -> Bool {
        ClientAttentionRules.needsAttention(
            client: client,
            nextPendingTouchpoint: nextTouchpoint(for: client.id),
            outstandingValue: outstandingValue(for: client.id),
            now: .now,
            calendar: calendar
        )
    }

    private func nextContactText(for client: ClientRecord) -> String {
        if let dueAt = nextTouchpoint(for: client.id)?.dueAt ?? client.nextContactAt {
            return AppFormatters.relativeDueText(dueAt, calendar: calendar)
        }
        return "未安排"
    }

    private func lifetimeValue(for clientID: UUID) -> Double {
        visibleBookings
            .filter { $0.clientID == clientID }
            .reduce(0) { $0 + $1.fee }
    }

    private func outstandingValue(for clientID: UUID) -> Double {
        visibleBookings
            .filter { $0.clientID == clientID }
            .reduce(0) { $0 + store.outstandingAmount(for: $1) }
    }

    private func nextTouchpoint(for clientID: UUID) -> TouchpointRecord? {
        let items = store.touchpoints(for: clientID, includeArchived: scope == .archived)
        return items
            .filter { scope == .archived ? $0.isArchived : $0.isArchived == false }
            .filter { scope == .archived || $0.isComplete == false }
            .sorted { $0.dueAt < $1.dueAt }
            .first
    }

    private func tierSymbol(for tier: ClientTier) -> String {
        switch tier {
        case .standard:
            "circle.fill"
        case .focus:
            "star.leadinghalf.filled"
        case .signature:
            "crown.fill"
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        AppSectionHeader(title: title, subtitle: subtitle)
    }

    private func emptyStateRow(title: String, subtitle: String) -> some View {
        AppEmptyState(title: title, subtitle: subtitle, systemImage: "person.2")
    }
}


private struct ClientSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchText: String
    let clients: [ClientRecord]
    let scope: ClientScope

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
                        promptCard
                    } else if clients.isEmpty {
                        emptyCard
                    } else {
                        resultCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索客户、城市、来源、手机号")
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
        GlassCard(title: scope == .active ? "搜索主列表" : "搜索归档", subtitle: isEmptyQuery ? "输入客户名、城市、来源或手机号。" : "共找到 \(clients.count) 位相关客户") {
            EmptyView()
        }
    }

    private var promptCard: some View {
        GlassCard(title: "开始搜索", subtitle: "支持搜索客户名、城市、来源渠道与手机号。") {
            EmptyView()
        }
    }

    private var emptyCard: some View {
        GlassCard(title: "没有找到相关客户", subtitle: "换一个关键词试试，或回到筛选页调整范围和排序。") {
            EmptyView()
        }
    }

    private var resultCard: some View {
        let resultTitle = "\(clients.count) 个结果"

        return GlassCard(title: resultTitle, subtitle: "按当前筛选条件展示") {
            VStack(spacing: 0) {
                ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                    clientResultRow(for: client)

                    if index < clients.count - 1 {
                        Divider()
                            .overlay(AppTheme.line.opacity(0.72))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clientResultRow(for client: ClientRecord) -> some View {
        let locationParts = [client.city, client.sourceChannel].filter { $0.isEmpty == false }
        let locationText = locationParts.isEmpty ? "未补充城市与来源" : locationParts.joined(separator: " · ")
        let contactText = [client.phoneNumber, client.wechatID, client.emailAddress].first(where: { $0.isEmpty == false }) ?? "暂无联系方式"

        NavigationLink {
            ClientDetailView(clientID: client.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(client.name)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)

                Text(locationText)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)

                Text(contactText)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
