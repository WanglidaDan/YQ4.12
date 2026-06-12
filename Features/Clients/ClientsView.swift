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

    private var totalClientCount: Int {
        sourceClients.count
    }

    private var totalRelationshipValue: Double {
        sourceClients.reduce(0) { $0 + lifetimeValue(for: $1.id) }
    }

    private var totalReceivableValue: Double {
        sourceClients.reduce(0) { $0 + outstandingValue(for: $1.id) }
    }

    private var isPristineClients: Bool {
        sourceClients.isEmpty && filter == .all && trimmedSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerBar

                        if isPristineClients {
                            clientsStartState
                        } else {
                            relationshipRadar
                            filterDock
                            relationshipList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
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

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("关系")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Spacer()

                HStack(spacing: 10) {
                    headerIconButton(systemImage: "magnifyingglass") {
                        showingSearchSheet = true
                        AppHaptics.tapLight()
                    }
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.panelStrong, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("筛选客户")
                }
            }

            inlineSearchBar
        }
    }

    private var headerSubtitle: String {
        if scope == .archived {
            return "归档关系 · \(totalClientCount) 位"
        }
        if attentionCount > 0 {
            return "\(attentionCount) 位需要跟进 · \(receivableCount) 位待回款"
        }
        return "客户、跟进、价值和回款统一管理"
    }

    private func headerIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 42, height: 42)
                .background(AppTheme.panelStrong, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var inlineSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)

            TextField("搜索客户、城市、来源、手机号", text: $searchText)
                .font(.system(size: 15, weight: .semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if trimmedSearchText.isEmpty == false {
                Button {
                    searchText = ""
                    AppHaptics.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line.opacity(0.70), lineWidth: 1)
        }
    }

    private var relationshipRadar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(scope == .active ? "关系雷达" : "归档关系")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(radarSubtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totalClientCount)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("CLIENTS")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.64))
                }
            }

            Divider()
                .overlay(.white.opacity(0.18))

            HStack(spacing: 0) {
                radarColumn(title: "需跟进", value: "\(attentionCount)", footnote: "优先处理")
                radarDivider
                radarColumn(title: "高价值", value: "\(signatureCount)", footnote: "重点维护")
                radarDivider
                radarColumn(title: "待回款", value: "\(receivableCount)", footnote: AppFormatters.currency(totalReceivableValue))
            }

            Divider()
                .overlay(.white.opacity(0.18))

            HStack(alignment: .firstTextBaseline) {
                Text("关系资产")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Text(AppFormatters.currency(totalRelationshipValue))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .padding(22)
        .background(radarBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.16), radius: 22, y: 12)
    }

    private var radarBackground: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 150, height: 150)
                .offset(x: 68, y: -76)

            LinearGradient(
                colors: [.white.opacity(0.12), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var radarSubtitle: String {
        if scope == .archived {
            return "保留历史订单、跟进和客户价值记录"
        }
        if attentionCount > 0 {
            return "先处理跟进，再维护高价值客户"
        }
        return "当前关系状态稳定，适合继续拓展"
    }

    private func radarColumn(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
            Text(footnote)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var radarDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 54)
            .padding(.horizontal, 14)
    }

    private var filterDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("视图")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(filter.title) · \(sort.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(ClientFilter.allCases) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                filter = item
                            }
                            AppHaptics.selection()
                        } label: {
                            VStack(spacing: 7) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(filter == item ? AppTheme.accent : AppTheme.secondaryInk)
                                Rectangle()
                                    .fill(filter == item ? AppTheme.accent : .clear)
                                    .frame(height: 3)
                                    .clipShape(Capsule())
                            }
                            .frame(minWidth: 58)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var clientsStartState: some View {
        VStack(alignment: .leading, spacing: 18) {
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scope == .active ? "客户关系" : "归档客户")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(listSummaryText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Spacer()

                if filter != .all || trimmedSearchText.isEmpty == false {
                    Button("重置") {
                        filter = .all
                        searchText = ""
                        AppHaptics.selection()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 12)

            if filteredClients.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredClients.enumerated()), id: \.element.id) { item in
                        clientRow(item.element)
                        if item.offset < filteredClients.count - 1 {
                            rowDivider
                        }
                    }
                }
                .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
                }
            }
        }
    }

    private var listSummaryText: String {
        if filteredClients.isEmpty { return "当前没有符合条件的客户" }
        return "\(filteredClients.count) 位 · \(filter.title) · \(sort.title)"
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(emptyTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text(emptySubtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private var emptyTitle: String {
        if trimmedSearchText.isEmpty == false { return "没有找到相关客户" }
        return scope == .active ? "还没有客户数据" : "还没有归档客户"
    }

    private var emptySubtitle: String {
        if trimmedSearchText.isEmpty == false { return "换个关键词试试，或者重置筛选。" }
        return scope == .active ? "点击右下角新建客户，先记录一个真实关系。" : "归档客户会显示在这里。"
    }

    private func clientRow(_ client: ClientRecord) -> some View {
        NavigationLink(value: ClientRoute(clientID: client.id)) {
            HStack(alignment: .top, spacing: 14) {
                Text(client.initials)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(client.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)

                        if scope == .active && clientNeedsAttention(client) {
                            Text("需跟进")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }

                        Spacer(minLength: 8)
                    }

                    Text("\(client.stage.title) / \(client.tier.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)

                    Text(clientMetaText(for: client))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)

                    Text(nextContactText(for: client))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(clientNeedsAttention(client) ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                VStack(alignment: .trailing, spacing: 7) {
                    Text(AppFormatters.currency(lifetimeValue(for: client.id)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    let outstanding = outstandingValue(for: client.id)
                    if outstanding > 0 {
                        Text("待收 \(AppFormatters.currency(outstanding))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .frame(minWidth: 82, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
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

    private var addClientButton: some View {
        Button {
            showingNewClient = true
            AppHaptics.impactMedium()
        } label: {
            Label("新建客户", systemImage: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(AppTheme.accent, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: AppTheme.deepShadow.opacity(0.28), radius: 16, x: 0, y: 9)
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
            .padding(.leading, 68)
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
                    .frame(height: 48)
                    .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
                    }
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
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索客户")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
        }
    }
}
