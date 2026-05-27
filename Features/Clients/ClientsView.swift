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

    private var followUpClientCount: Int {
        sourceClients.filter(clientNeedsAttention).count
    }

    private var outstandingTotal: Double {
        sourceClients.reduce(0) { $0 + outstandingValue(for: $1.id) }
    }

    private var filterSummary: String {
        [scope.title, filter.title, sort.title].joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "关系", topPadding: 6, bottomPadding: 32) {
                compactControls
                relationshipList
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        AppHaptics.tapLight()
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("筛选")

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
                Text("若该客户已经关联订单或跟进，系统会自动改为归档而不是直接删除。")
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

    private var compactControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                inlineSearchField

                Button {
                    AppHaptics.impactMedium()
                    showingNewClient = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.panelStrong)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增客户")
            }

            Picker("范围", selection: $scope) {
                ForEach(ClientScope.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

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
                            .overlay {
                                Capsule().stroke(AppTheme.line.opacity(0.56), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
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

    private var inlineSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 20)

            TextField("搜索客户、城市、来源", text: $searchText)
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
        .frame(height: 46)
        .background(AppTheme.inputSurface, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.58), lineWidth: 1)
        }
    }

    private var relationshipList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scope == .active ? "客户列表" : "归档客户")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppTheme.ink)

                    Text(listSummaryText)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Spacer(minLength: 8)

                if followUpClientCount > 0 && scope == .active {
                    Text("\(followUpClientCount) 待经营")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.warning)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(AppTheme.accentWarmSoft, in: Capsule())
                }
            }

            if filteredClients.isEmpty {
                AppEmptyState(title: emptyTitle, subtitle: emptySubtitle, systemImage: "person.2")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredClients.enumerated()), id: \.element.id) { index, client in
                        simpleClientRow(client)

                        if index < filteredClients.count - 1 {
                            Divider()
                                .overlay(AppTheme.line.opacity(0.56))
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel, strokeOpacity: 0.74)
    }

    private var listSummaryText: String {
        if filteredClients.isEmpty { return "当前没有符合条件的客户" }
        let amountText = outstandingTotal > 0 ? " · 待回款 \(AppFormatters.currency(outstandingTotal))" : ""
        return "\(filteredClients.count) 位 · \(filter.title) · \(sort.title)\(amountText)"
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
                Picker("类型", selection: $filter) {
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
                .pickerStyle(.segmented)
            }
        }
    }

    private var emptyTitle: String {
        if trimmedSearchText.isEmpty == false { return "没有找到相关客户" }
        return scope == .active ? "还没有客户数据" : "还没有归档客户"
    }

    private var emptySubtitle: String {
        if trimmedSearchText.isEmpty == false { return "换个关键词试试。" }
        return scope == .active ? "点击右上角新增客户。" : "归档客户会显示在这里。"
    }

    private func simpleClientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            HStack(alignment: .top, spacing: 12) {
                clientAvatar(client)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(client.name)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)

                        if scope == .active && clientNeedsAttention(client) {
                            Text("待经营")
                                .font(AppTypography.badge)
                                .foregroundStyle(AppTheme.warning)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(AppTheme.accentWarmSoft, in: Capsule())
                        }

                        Spacer(minLength: 6)
                    }

                    HStack(spacing: 8) {
                        Text(client.stage.title)
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryInk)

                        Text("·")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)

                        Text(client.tier.title)
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Text(clientMetaText(for: client))
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)

                    if client.notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(client.notesText)
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .trailing, spacing: 7) {
                    Text(AppFormatters.currency(lifetimeValue(for: client.id)))
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    let outstanding = outstandingValue(for: client.id)
                    if outstanding > 0 {
                        Text("待收 \(AppFormatters.currency(outstanding))")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.priorityHigh)
                            .lineLimit(1)
                    }

                    Text(nextContactText(for: client))
                        .font(AppTypography.meta)
                        .foregroundStyle(clientNeedsAttention(client) ? AppTheme.warning : AppTheme.secondaryInk)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .frame(minWidth: 86, alignment: .trailing)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accentSurface)
                .frame(width: 44, height: 44)
            Text(client.initials)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.accentDeep)
        }
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
                        .stroke(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.line.opacity(0.58), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func clientMetaText(for client: ClientRecord) -> String {
        let locationText = [client.city, client.sourceChannel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
        let contactText = client.preferredContactText.trimmingCharacters(in: .whitespacesAndNewlines)

        if locationText.isEmpty && contactText.isEmpty { return "待补充客户信息" }
        if locationText.isEmpty { return contactText }
        if contactText.isEmpty || contactText == "暂无联系方式" { return locationText }
        return "\(locationText) · \(contactText)"
    }

    private func matches(filter: ClientFilter, client: ClientRecord) -> Bool {
        switch filter {
        case .all:
            return true
        case .signature:
            return client.tier == .signature
        case .followUp:
            return clientNeedsAttention(client)
        case .retained:
            return client.stage == .retained
        }
    }

    private func matches(searchText: String, client: ClientRecord) -> Bool {
        guard searchText.isEmpty == false else { return true }
        let haystack = [
            client.name,
            client.city,
            client.phoneNumber,
            client.wechatID,
            client.emailAddress,
            client.sourceChannel,
            client.notesText,
            client.tags.joined(separator: " ")
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)

        let needle = searchText
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)

        return haystack.contains(needle)
    }

    private func compareClients(_ lhs: ClientRecord, _ rhs: ClientRecord) -> Bool {
        switch sort {
        case .latest:
            return lhs.createdAt > rhs.createdAt
        case .value:
            let lhsValue = lifetimeValue(for: lhs.id)
            let rhsValue = lifetimeValue(for: rhs.id)
            if lhsValue == rhsValue { return lhs.createdAt > rhs.createdAt }
            return lhsValue > rhsValue
        case .followUp:
            let lhsNeedsAttention = clientNeedsAttention(lhs)
            let rhsNeedsAttention = clientNeedsAttention(rhs)
            if lhsNeedsAttention != rhsNeedsAttention { return lhsNeedsAttention }
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
                VStack(alignment: .leading, spacing: 14) {
                    if isEmptyQuery {
                        AppEmptyState(title: "搜索客户", subtitle: "输入客户名、城市、来源或联系方式。", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if clients.isEmpty {
                        AppEmptyState(title: "没有找到相关客户", subtitle: "换个关键词试试。", systemImage: "person.crop.circle.badge.questionmark")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(clients.count) 个结果")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppTheme.ink)
                                .padding(.bottom, 8)

                            ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                                clientResultRow(for: client)
                                if index < clients.count - 1 {
                                    Divider().overlay(AppTheme.line.opacity(0.6))
                                }
                            }
                        }
                        .padding(18)
                        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel, strokeOpacity: 0.72)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(scope == .active ? "搜索主列表" : "搜索归档")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索客户、城市、来源、手机号")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func clientResultRow(for client: ClientRecord) -> some View {
        let locationParts = [client.city, client.sourceChannel].filter { $0.isEmpty == false }
        let locationText = locationParts.isEmpty ? "未补充城市与来源" : locationParts.joined(separator: " · ")
        let contactText = client.preferredContactText

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
