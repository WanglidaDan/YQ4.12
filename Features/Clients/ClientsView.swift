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
    @State private var showingNewClient = false
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

    private var sourceClients: [ClientRecord] {
        switch scope {
        case .active: store.activeClients
        case .archived: store.archivedClients
        }
    }

    private var visibleBookings: [BookingRecord] {
        switch scope {
        case .active: store.activeBookings
        case .archived: store.archivedBookings
        }
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

    private var totalLifetimeValue: Double {
        visibleBookings.reduce(0) { $0 + $1.fee }
    }

    private var followUpClientCount: Int {
        sourceClients.filter(clientNeedsAttention).count
    }

    private var signatureClientCount: Int {
        sourceClients.filter { $0.tier == .signature }.count
    }

    private var retainedClientCount: Int {
        sourceClients.filter { $0.stage == .retained }.count
    }

    private var filterSummary: String {
        [scope.title, filter.title, sort.title].joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "客户", topPadding: 12, bottomPadding: 32) {
                relationshipHeader
                inlineSearchField
                relationshipControls

                if featuredClients.isEmpty == false {
                    clientsBlock(title: "今日优先", subtitle: "需要跟进、回款或高价值客户") {
                        ForEach(featuredClients) { client in
                            priorityClientRow(client)
                        }
                    }
                }

                clientsBlock(
                    title: scope == .active ? "全部客户" : "归档客户",
                    subtitle: filteredClients.isEmpty ? "当前没有符合条件的客户" : "\(filteredClients.count) 位 · \(filter.title) · \(sort.title)"
                ) {
                    if filteredClients.isEmpty {
                        emptyStateRow(
                            title: emptyTitle,
                            subtitle: emptySubtitle
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

                    Button {
                        AppHaptics.tapLight()
                        showingNewClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新增客户")
                }
            }
            .navigationDestination(for: ClientRoute.self) { route in
                ClientDetailView(clientID: route.clientID)
            }
            .sheet(isPresented: $showingNewClient) {
                ClientEditorView()
                    .environment(store)
            }
            .sheet(item: $editingClient) { client in
                ClientEditorView(client: client)
                    .environment(store)
            }
            .sheet(isPresented: $showingSearchSheet) {
                ClientSearchSheet(searchText: $searchText, clients: filteredClients, scope: scope)
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
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

    private var scopePicker: some View {
        Picker("范围", selection: $scope) {
            ForEach(ClientScope.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var relationshipHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scope == .active ? "客户关系" : "历史客户")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppTheme.ink)
                    Text(headerSubtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    AppHaptics.impactMedium()
                    showingNewClient = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.panelStrong)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增客户")
            }

            HStack(spacing: 0) {
                relationshipMetric(title: "客户", value: "\(sourceClients.count)")
                metricDivider
                relationshipMetric(title: "待经营", value: "\(followUpClientCount)", valueColor: followUpClientCount > 0 ? AppTheme.warning : AppTheme.ink)
                metricDivider
                relationshipMetric(title: "待回款", value: AppFormatters.currency(outstandingTotal), valueColor: outstandingTotal > 0 ? AppTheme.priorityHigh : AppTheme.ink)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(fillColor: AppTheme.panel)
    }

    private var inlineSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 20)

            TextField("搜索客户、来源、城市、电话", text: $searchText)
                .font(AppTypography.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if trimmedSearchText.isEmpty == false {
                Button {
                    searchText = ""
                    AppHaptics.tapLight()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.inputSurface, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
        }
    }

    private var relationshipControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            scopePicker

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClientFilter.allCases) { item in
                        filterChip(title: item.title, isSelected: filter == item) {
                            filter = item
                            AppHaptics.selection()
                        }
                    }

                    Menu {
                        Picker("排序", selection: $sort) {
                            ForEach(ClientSort.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    } label: {
                        Label(sort.title, systemImage: "arrow.up.arrow.down")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(AppTheme.panelSoft, in: Capsule())
                    }
                }
                .padding(.horizontal, 1)
            }

            if trimmedSearchText.isEmpty == false {
                Text("搜索结果：\(filteredClients.count) 位")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private var summaryStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                summaryMetric(title: "客户", value: "\(sourceClients.count)")
                summaryMetric(title: "待经营", value: "\(followUpClientCount)")
                summaryMetric(title: "签约额", value: AppFormatters.currency(totalLifetimeValue))
            }

            HStack(spacing: 8) {
                Label(filter.title, systemImage: "line.3.horizontal.decrease.circle")
                Text(sort.title)
                Spacer(minLength: 8)
                Button("调整") {
                    AppHaptics.tapLight()
                    showingFilterSheet = true
                }
                .font(AppTypography.meta.weight(.semibold))
            }
            .font(AppTypography.meta)
            .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(fillColor: AppTheme.panelSoft)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outstandingTotal: Double {
        sourceClients.reduce(0) { $0 + outstandingValue(for: $1.id) }
    }

    private var headerSubtitle: String {
        if scope == .archived {
            return "归档客户保留订单、回款和沟通历史。"
        }
        if followUpClientCount > 0 {
            return "先处理待跟进和待回款客户，再看完整名单。"
        }
        return "客户信息、合作价值和下一步动作集中查看。"
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(AppTheme.line.opacity(0.56))
            .frame(width: 1, height: 38)
            .padding(.horizontal, 10)
    }

    private func relationshipMetric(title: String, value: String, valueColor: Color = AppTheme.ink) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.panelStrong : AppTheme.secondaryInk)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(isSelected ? AppTheme.accent : AppTheme.panelSoft, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.line.opacity(0.68), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scope == .active ? "客户经营" : "历史客户")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    Text(scope == .active ? "客户关系工作台" : "客户归档库")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Text("\(sourceClients.count) 位")
                    .font(AppTypography.badge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.26), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(heroTitle)
                    .font(AppTypography.heroTitle)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroSubtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                heroActionButton(title: "新增客户", systemImage: "person.badge.plus") {
                    AppHaptics.impactMedium()
                    showingNewClient = true
                }

                heroActionButton(title: "搜索客户", systemImage: "magnifyingglass") {
                    AppHaptics.tapLight()
                    showingSearchSheet = true
                }

                heroActionButton(title: "筛选", systemImage: "line.3.horizontal.decrease.circle") {
                    AppHaptics.tapLight()
                    showingFilterSheet = true
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepShadow.opacity(0.14), radius: AppShadow.heroRadius, y: AppShadow.heroY)
    }

    private var controlCard: some View {
        GlassCard(title: "客户概览", subtitle: filterSummary) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AppMetricTile(title: "客户总数", value: "\(sourceClients.count)", subtitle: scope.title)
                    AppMetricTile(title: "累计签约", value: AppFormatters.currency(totalLifetimeValue), subtitle: "订单累计")
                }

                HStack(spacing: 12) {
                    AppMetricTile(title: "高价值", value: "\(signatureClientCount)", subtitle: "签名客户")
                    AppMetricTile(title: "待经营", value: "\(followUpClientCount)", subtitle: "需关注")
                    AppMetricTile(title: "长期", value: "\(retainedClientCount)", subtitle: "复购沉淀")
                }

                Picker("范围", selection: $scope) {
                    ForEach(ClientScope.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

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
    }

    private var filterSheet: some View {
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

    private var heroTitle: String {
        if scope == .archived { return "历史合作沉淀" }
        if followUpClientCount > 0 { return "今天有 \(followUpClientCount) 位客户需要关注" }
        if sourceClients.isEmpty { return "从第一个客户开始" }
        return "客户、跟进、回款集中管理"
    }

    private var heroSubtitle: String {
        if scope == .archived { return "保留订单、回款与沟通记录。" }
        if followUpClientCount > 0 { return "优先处理跟进与待回款。" }
        return "来源、阶段、价值、下次跟进。"
    }

    private var emptyTitle: String {
        if trimmedSearchText.isEmpty == false { return "没有找到相关客户" }
        return scope == .active ? "还没有客户数据" : "还没有归档客户"
    }

    private var emptySubtitle: String {
        if trimmedSearchText.isEmpty == false { return "换个关键词试试。" }
        return scope == .active ? "点击顶部新增客户。" : "归档客户会显示在这里。"
    }

    private func heroActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    clientAvatar(client)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(client.name)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)

                            if scope == .active && clientNeedsAttention(client) {
                                attentionBadge
                            }
                        }

                        HStack(spacing: 8) {
                            LeadStageBadge(stage: client.stage)
                            tierLabel(for: client.tier)
                        }

                        Text(clientMetaText(for: client))
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(nextContactText(for: client))
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(clientNeedsAttention(client) ? AppTheme.warning : AppTheme.secondaryInk)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }

                if client.notesText.isEmpty == false {
                    Text(client.notesText)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                        .padding(.leading, 56)
                }

                HStack(spacing: 10) {
                    clientRowMetric(title: "累计", value: AppFormatters.currency(lifetimeValue(for: client.id)))
                    clientRowMetric(
                        title: "待回款",
                        value: AppFormatters.currency(outstandingValue(for: client.id)),
                        valueColor: outstandingValue(for: client.id) > 0 ? AppTheme.priorityHigh : AppTheme.ink
                    )
                    clientRowMetric(title: "下次", value: nextContactText(for: client))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .appCardSurface(fillColor: AppTheme.panelStrong)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            .tint(AppTheme.accent)

            Button(scope == .active ? "归档" : "恢复", systemImage: scope == .active ? "archivebox" : "arrow.uturn.backward.circle") {
                if scope == .active { store.archiveClient(client.id) } else { store.restoreClient(client.id) }
            }
            .tint(scope == .active ? AppTheme.secondaryInk : AppTheme.success)

            Button("删除", systemImage: "trash", role: .destructive) {
                deletingClient = client
            }
        }
        .contextMenu {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            if scope == .active {
                Button("归档", systemImage: "archivebox") { store.archiveClient(client.id) }
            } else {
                Button("恢复到主列表", systemImage: "arrow.uturn.backward.circle") { store.restoreClient(client.id) }
            }
            Button(role: .destructive) { deletingClient = client } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func priorityClientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Circle()
                        .fill(priorityColor(for: client))
                        .frame(width: 10, height: 10)
                    Rectangle()
                        .fill(priorityColor(for: client).opacity(0.22))
                        .frame(width: 2, height: 58)
                        .clipShape(Capsule())
                }
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(client.name)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)

                        LeadStageBadge(stage: client.stage)

                        Spacer(minLength: 8)

                        Text(nextContactText(for: client))
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(priorityColor(for: client))
                            .lineLimit(1)
                    }

                    Text(priorityReason(for: client))
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        compactValue(title: "累计", value: AppFormatters.currency(lifetimeValue(for: client.id)))
                        compactValue(
                            title: "待回款",
                            value: AppFormatters.currency(outstandingValue(for: client.id)),
                            valueColor: outstandingValue(for: client.id) > 0 ? AppTheme.priorityHigh : AppTheme.ink
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .appCardSurface(fillColor: AppTheme.panelStrong)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            .tint(AppTheme.accent)

            Button(scope == .active ? "归档" : "恢复", systemImage: scope == .active ? "archivebox" : "arrow.uturn.backward.circle") {
                if scope == .active { store.archiveClient(client.id) } else { store.restoreClient(client.id) }
            }
            .tint(scope == .active ? AppTheme.secondaryInk : AppTheme.success)

            Button("删除", systemImage: "trash", role: .destructive) {
                deletingClient = client
            }
        }
        .contextMenu {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            if scope == .active {
                Button("归档", systemImage: "archivebox") { store.archiveClient(client.id) }
            } else {
                Button("恢复到主列表", systemImage: "arrow.uturn.backward.circle") { store.restoreClient(client.id) }
            }
            Button(role: .destructive) { deletingClient = client } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func clientAvatar(_ client: ClientRecord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.accentSurface)
                .frame(width: 44, height: 44)
            Text(client.initials)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.accentDeep)
        }
    }

    private func clientRowMetric(title: String, value: String, valueColor: Color = AppTheme.ink) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.panelSoft, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func compactValue(title: String, value: String, valueColor: Color = AppTheme.ink) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(AppTypography.meta.weight(.semibold))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(AppTheme.panelSoft, in: Capsule())
    }

    private func priorityColor(for client: ClientRecord) -> Color {
        if outstandingValue(for: client.id) > 0 { return AppTheme.priorityHigh }
        if clientNeedsAttention(client) { return AppTheme.warning }
        return AppTheme.accent
    }

    private func priorityReason(for client: ClientRecord) -> String {
        let outstanding = outstandingValue(for: client.id)
        if outstanding > 0 {
            return "还有 \(AppFormatters.currency(outstanding)) 待回款，建议优先确认。"
        }
        if let dueAt = nextTouchpoint(for: client.id)?.dueAt ?? client.nextContactAt {
            return "下一次跟进：\(AppFormatters.relativeDueText(dueAt, calendar: calendar))。"
        }
        if client.tier == .signature {
            return "高价值客户，建议保持主动经营。"
        }
        return "需要补充下一步动作。"
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
        case .all: true
        case .signature: client.tier == .signature
        case .followUp: clientNeedsAttention(client)
        case .retained: client.stage == .retained
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
            if lhsDate == rhsDate { return lifetimeValue(for: lhs.id) > lifetimeValue(for: rhs.id) }
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
        case .standard: "circle.fill"
        case .focus: "star.leadinghalf.filled"
        case .signature: "crown.fill"
        }
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
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var searchHeroCard: some View {
        GlassCard(title: scope == .active ? "搜索主列表" : "搜索归档", subtitle: isEmptyQuery ? "输入关键词。" : "\(clients.count) 个结果") {
            EmptyView()
        }
    }

    private var promptCard: some View {
        GlassCard(title: "开始搜索", subtitle: "客户名、城市、来源、手机号") { EmptyView() }
    }

    private var emptyCard: some View {
        GlassCard(title: "没有找到相关客户", subtitle: "换个关键词试试。") { EmptyView() }
    }

    private var resultCard: some View {
        GlassCard(title: "\(clients.count) 个结果", subtitle: "按当前筛选条件展示") {
            VStack(spacing: 0) {
                ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                    clientResultRow(for: client)

                    if index < clients.count - 1 {
                        Divider().overlay(AppTheme.line.opacity(0.72))
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
