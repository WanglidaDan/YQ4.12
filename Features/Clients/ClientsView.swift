import SwiftUI

private enum ClientFilter: String, CaseIterable, Identifiable {
    case all
    case attention
    case signature
    case retained
    case receivable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .attention: "需跟进"
        case .signature: "高价值"
        case .retained: "长期"
        case .receivable: "待回款"
        }
    }
}

private enum ClientSort: String, CaseIterable, Identifiable {
    case followUp
    case latest
    case value

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followUp: "跟进优先"
        case .latest: "最近新增"
        case .value: "价值优先"
        }
    }
}

private enum ClientScope: String, CaseIterable, Identifiable {
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
    @State private var toastMessage: String?

    private let calendar = Calendar.current

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceClients: [ClientRecord] {
        scope == .active ? store.activeClients : store.archivedClients
    }

    private var visibleBookings: [BookingRecord] {
        scope == .active ? store.activeBookings : store.archivedBookings
    }

    private var filteredClients: [ClientRecord] {
        sourceClients
            .filter(matchesFilter)
            .filter(matchesSearch)
            .sorted(by: compareClients)
    }

    private var isPristineClients: Bool {
        sourceClients.isEmpty && filter == .all && trimmedSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if isPristineClients {
                        clientsStartState
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if filteredClients.isEmpty {
                        emptyState
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(filteredClients) { client in
                                clientRow(client)
                            }
                        } header: {
                            Text("\(filteredClients.count) 位客户")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background.ignoresSafeArea())

                if let toastMessage {
                    AppToast(message: toastMessage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(for: ClientRoute.self) { route in
                ClientDetailView(clientID: route.clientID)
            }
            .sheet(isPresented: $showingNewClient) {
                ClientEditorView { savedClient in
                    showSavedToast(for: savedClient)
                }
                .environment(store)
            }
            .sheet(item: $editingClient) { client in
                ClientEditorView(client: client) { savedClient in
                    showSavedToast(for: savedClient)
                }
                .environment(store)
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
            .navigationTitle("客户")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索客户、城市或联系方式")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu("筛选", systemImage: "line.3.horizontal.decrease") {
                        Picker("范围", selection: $scope) {
                            ForEach(ClientScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        Picker("排序", selection: $sort) {
                            ForEach(ClientSort.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }

                        Picker("状态", selection: $filter) {
                            ForEach(ClientFilter.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }

                    Button("新建客户", systemImage: "plus") {
                        showingNewClient = true
                        AppHaptics.impactMedium()
                    }
                }
            }
        }
    }

    private var clientsStartState: some View {
        ContentUnavailableView(
            scope == .active ? "暂无客户" : "暂无归档",
            systemImage: scope == .active ? "person.2" : "archivebox"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        ContentUnavailableView(emptyTitle, systemImage: "person.crop.circle.badge.questionmark")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var emptyTitle: String {
        if trimmedSearchText.isEmpty == false { return "没有找到相关客户" }
        return scope == .active ? "还没有客户数据" : "还没有归档客户"
    }

    private func clientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            HStack(spacing: 12) {
                Text(client.initials)
                    .font(AppTypography.badge)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accentSurface, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text(clientMetaText(for: client))
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if clientNeedsAttention(client) {
                    Text("待跟进")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing) {
            Button("编辑", systemImage: "square.and.pencil") {
                editingClient = client
            }
            .tint(AppTheme.accent)

            Button(scope == .active ? "归档" : "恢复", systemImage: scope == .active ? "archivebox" : "arrow.uturn.backward") {
                if scope == .active {
                    store.archiveClient(client.id)
                } else {
                    store.restoreClient(client.id)
                }
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

    private func matchesFilter(_ client: ClientRecord) -> Bool {
        switch filter {
        case .all:
            return true
        case .attention:
            return clientNeedsAttention(client)
        case .signature:
            return client.tier == .signature
        case .retained:
            return client.stage == .retained
        case .receivable:
            return outstandingValue(for: client.id) > 0
        }
    }

    private func matchesSearch(_ client: ClientRecord) -> Bool {
        guard trimmedSearchText.isEmpty == false else { return true }
        return AppFormatters.matchesSearch(trimmedSearchText, terms: [
            client.name,
            client.city,
            client.phoneNumber,
            client.wechatID,
            client.emailAddress,
            client.sourceChannel,
            client.notesText,
            client.tags.joined(separator: " ")
        ])
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

    private func showSavedToast(for client: ClientRecord) {
        withAnimation(.snappy(duration: 0.2)) {
            toastMessage = "已保存：\(client.name)"
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy(duration: 0.2)) {
                if toastMessage == "已保存：\(client.name)" {
                    toastMessage = nil
                }
            }
        }
    }
}
