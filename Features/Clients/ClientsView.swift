import SwiftUI
import UIKit

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
    @State private var showingSearchSheet = false
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

    private var attentionCount: Int {
        sourceClients.filter(clientNeedsAttention).count
    }

    private var signatureCount: Int {
        sourceClients.filter { $0.tier == .signature }.count
    }

    private var receivableCount: Int {
        sourceClients.filter { outstandingValue(for: $0.id) > 0 }.count
    }

    private var retainedCount: Int {
        sourceClients.filter { $0.stage == .retained }.count
    }

    private var totalClientCount: Int {
        sourceClients.count
    }

    private var isPristineClients: Bool {
        sourceClients.isEmpty && filter == .all && trimmedSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBar

                        if isPristineClients {
                            clientsStartState
                        } else {
                            overviewStrip
                            quickFilterRow
                            relationshipList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }

                addClientButton
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
            .sheet(isPresented: $showingSearchSheet) {
                ClientSearchSheet(
                    searchText: $searchText,
                    clients: filteredClients,
                    nextContactText: nextContactText,
                    lifetimeValue: lifetimeValue,
                    outstandingValue: outstandingValue
                )
                .presentationDetents([.medium, .large])
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var pageBackground: some View {
        AppTheme.backgroundGradient
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("关系")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(scope.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
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
            .accessibilityLabel("搜索客户")

            Menu {
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
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("筛选客户")
        }
    }

    private var overviewStrip: some View {
        HStack(spacing: 0) {
            compactMetric("客户", value: totalClientCount)
            Divider().frame(height: 30)
            compactMetric("需跟进", value: attentionCount)
            Divider().frame(height: 30)
            compactMetric("待回款", value: receivableCount)
            Divider().frame(height: 30)
            compactMetric("长期", value: retainedCount)
        }
        .padding(.vertical, 16)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private func compactMetric(_ title: String, value: Int) -> some View {
        VStack(spacing: 5) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ClientFilter.allCases) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            filter = item
                        }
                        AppHaptics.selection()
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

    private var clientsStartState: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppCreateHeader(
                eyebrow: scope == .active ? "开始关系库" : "归档",
                title: scope == .active ? "先记录一个客户" : "还没有归档客户",
                subtitle: scope == .active ? "只填昵称、电话或微信中的任意一项即可保存，后面再补来源和跟进。" : "归档后的客户会显示在这里。",
                systemImage: scope == .active ? "person.badge.plus" : "archivebox"
            )

            if scope == .active {
                Button {
                    showingNewClient = true
                    AppHaptics.impactMedium()
                } label: {
                    Label("新建客户", systemImage: "plus")
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
    }

    private var relationshipList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scope == .active ? "客户列表" : "归档客户")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(listSummaryText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if filter != .all || trimmedSearchText.isEmpty == false {
                    Button("重置") {
                        filter = .all
                        searchText = ""
                        AppHaptics.selection()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.plain)
                }
            }

            if filteredClients.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredClients) { client in
                        clientRow(client)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var listSummaryText: String {
        if filteredClients.isEmpty { return "当前没有符合条件的客户" }
        return "\(filteredClients.count) 位 · \(filter.title) · \(sort.title)"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
            Text(emptySubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyTitle: String {
        if trimmedSearchText.isEmpty == false { return "没有找到相关客户" }
        return scope == .active ? "还没有客户数据" : "还没有归档客户"
    }

    private var emptySubtitle: String {
        if trimmedSearchText.isEmpty == false { return "换个关键词试试。" }
        return scope == .active ? "点击右下角新建客户，先记录一个真实关系。" : "归档客户会显示在这里。"
    }

    private func clientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            HStack(alignment: .top, spacing: 12) {
                clientAvatar(client)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(client.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if scope == .active && clientNeedsAttention(client) {
                            Text("需跟进")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        }

                        Spacer(minLength: 8)
                    }

                    HStack(spacing: 8) {
                        Text(client.stage.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(client.tier.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(clientMetaText(for: client))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(nextContactText(for: client))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(clientNeedsAttention(client) ? .orange : .secondary)
                        .lineLimit(1)
                }

                VStack(alignment: .trailing, spacing: 7) {
                    Text(AppFormatters.currency(lifetimeValue(for: client.id)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    let outstanding = outstandingValue(for: client.id)
                    if outstanding > 0 {
                        Text("待收 \(AppFormatters.currency(outstanding))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 78, alignment: .trailing)
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 46, height: 46)
            Text(client.initials)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var addClientButton: some View {
        Button {
            showingNewClient = true
            AppHaptics.impactMedium()
        } label: {
            Label("新建客户", systemImage: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.panelStrong)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.deepShadow.opacity(0.6), radius: 18, x: 0, y: 10)
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

private struct ClientSearchSheet: View {
    @Binding var searchText: String
    let clients: [ClientRecord]
    let nextContactText: (ClientRecord) -> String
    let lifetimeValue: (UUID) -> Double
    let outstandingValue: (UUID) -> Double

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("搜索客户、城市、来源、手机号", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 18)

                if clients.isEmpty {
                    ContentUnavailableView("暂无结果", systemImage: "magnifyingglass", description: Text("换个关键词试试。"))
                        .frame(maxHeight: .infinity)
                } else {
                    List(clients.prefix(30)) { client in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(client.name)
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(client.city.isEmpty ? client.sourceChannel : client.city) · \(nextContactText(client)) · \(AppFormatters.currency(lifetimeValue(client.id)))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            let outstanding = outstandingValue(client.id)
                            if outstanding > 0 {
                                Text("待收 \(AppFormatters.currency(outstanding))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索客户")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
