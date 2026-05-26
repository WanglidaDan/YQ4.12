import SwiftUI
import Charts
import UIKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

enum BusinessCenterMode: String, CaseIterable, Identifiable {
    case workflow
    case assets
    case collaboration
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workflow: "业务闭环"
        case .assets: "资料中心"
        case .collaboration: "团队权限"
        case .analytics: "经营报表"
        }
    }

    var symbolName: String {
        switch self {
        case .workflow: "doc.text.fill"
        case .assets: "paperclip.circle.fill"
        case .collaboration: "person.3.sequence.fill"
        case .analytics: "chart.bar.xaxis"
        }
    }
}


struct BusinessCenterRoute: Identifiable, Hashable {
    let mode: BusinessCenterMode
    var bookingID: UUID?
    var clientID: UUID?

    var id: String {
        [mode.rawValue, bookingID?.uuidString ?? "all", clientID?.uuidString ?? "all"].joined(separator: "-")
    }
}

struct BusinessCenterView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookingID: UUID?
    let clientID: UUID?

    @State private var selectedMode: BusinessCenterMode
    @State private var selectedBookingID: UUID?
    @State private var editingDocument: BusinessDocumentRecord?
    @State private var editingAttachment: AttachmentRecord?
    @State private var editingMember: WorkspaceMemberRecord?
    @State private var presentingFileImporter = false
    @State private var pendingImportCategory: AttachmentCategory = .reference
    @State private var alertMessage: String?

    init(initialMode: BusinessCenterMode = .workflow, bookingID: UUID? = nil, clientID: UUID? = nil) {
        self.bookingID = bookingID
        self.clientID = clientID
        _selectedMode = State(initialValue: initialMode)
        _selectedBookingID = State(initialValue: bookingID)
    }

    private var selectedBooking: BookingRecord? {
        let effectiveBookingID = bookingID ?? selectedBookingID
        return effectiveBookingID.flatMap { store.booking(id: $0) }
    }

    private var selectedClient: ClientRecord? {
        if let clientID {
            return store.client(id: clientID)
        }
        if let booking = selectedBooking, let bookingClientID = booking.clientID {
            return store.client(id: bookingClientID)
        }
        return nil
    }

    private var effectiveBookingID: UUID? {
        selectedBooking?.id ?? bookingID ?? selectedBookingID
    }

    private var effectiveClientID: UUID? {
        selectedClient?.id ?? clientID
    }

    private var scopedDocuments: [BusinessDocumentRecord] {
        store.documents(for: effectiveBookingID, clientID: effectiveClientID)
    }

    private var scopedAttachments: [AttachmentRecord] {
        store.attachments(for: effectiveBookingID, clientID: effectiveClientID)
    }

    private var scopeTitle: String {
        if let booking = selectedBooking {
            return booking.title
        }
        if let client = selectedClient {
            return client.name
        }
        return "整个工作区"
    }

    private var upcomingBookingCandidates: [BookingRecord] {
        let bookings = store.upcomingBookings(within: 180)
        return bookings.isEmpty ? store.activeBookings : bookings
    }

    private var latestWorkflowDocumentsByKind: [BusinessDocumentKind: BusinessDocumentRecord] {
        Dictionary(grouping: scopedDocuments, by: \.kind)
            .compactMapValues { documents in
                documents.max { $0.updatedAt < $1.updatedAt }
            }
    }

    private var completedWorkflowStepCount: Int {
        BusinessDocumentKind.allCases.filter { kind in
            guard let document = latestWorkflowDocumentsByKind[kind] else { return false }
            return document.status != .draft && document.status != .voided
        }.count
    }

    private var nextWorkflowKind: BusinessDocumentKind? {
        BusinessDocumentKind.allCases.first { kind in
            guard let document = latestWorkflowDocumentsByKind[kind] else { return true }
            return document.status == .draft || document.status == .voided
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    heroSection
                    modeSelector

                    switch selectedMode {
                    case .workflow:
                        workflowSection
                    case .assets:
                        assetsSection
                    case .collaboration:
                        collaborationSection
                    case .analytics:
                        analyticsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("经营中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            .sheet(item: $editingDocument) { document in
                BusinessDocumentEditorView(
                    initialDocument: document,
                    relatedBooking: document.bookingID.flatMap { store.booking(id: $0) },
                    relatedClient: document.clientID.flatMap { store.client(id: $0) }
                )
                .environment(store)
            }
            .sheet(item: $editingAttachment) { attachment in
                AttachmentEditorView(initialAttachment: attachment)
                    .environment(store)
            }
            .sheet(item: $editingMember) { member in
                WorkspaceMemberEditorView(initialMember: member)
                    .environment(store)
            }
            .fileImporter(
                isPresented: $presentingFileImporter,
                allowedContentTypes: allowedImportTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if $0 == false { alertMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                if selectedBookingID == nil {
                    selectedBookingID = upcomingBookingCandidates.first?.id
                }
            }
        }
    }

    private var heroSection: some View {
        AppInfoCard(title: scopeTitle, subtitle: "围绕合同、资料、团队权限和报表形成完整闭环。") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AppMetricTile(title: "文档", value: "\(scopedDocuments.count)", subtitle: "合同 / 报价 / 收据 / 发票")
                AppMetricTile(title: "资料", value: "\(scopedAttachments.count)", subtitle: "参考图、合同附件、交付素材")
                AppMetricTile(title: "团队成员", value: "\(store.activeWorkspaceMembers.count)", subtitle: store.currentWorkspaceRole.title)
                AppMetricTile(
                    title: "待收金额",
                    value: selectedBooking.map { AppFormatters.currency(store.outstandingAmount(for: $0)) } ?? AppFormatters.currency(store.analyticsDashboard.totalOutstandingAmount),
                    subtitle: selectedBooking == nil ? "整个工作区" : "当前订单"
                )
            }

            if bookingID == nil, upcomingBookingCandidates.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("切换当前聚焦订单")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    Menu {
                        ForEach(upcomingBookingCandidates) { booking in
                            Button(booking.title) {
                                selectedBookingID = booking.id
                            }
                        }
                    } label: {
                        AppSettingRow(title: "当前订单", value: selectedBooking?.title ?? "未选择")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .appCardSurface(fillColor: AppTheme.panelStrong)
                    }
                }
            }
        }
    }

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BusinessCenterMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedMode = mode
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                            Text(mode.title)
                                .font(AppTypography.meta.weight(.semibold))
                        }
                        .foregroundStyle(selectedMode == mode ? Color.white : AppTheme.secondaryInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedMode == mode ? AppTheme.accent : AppTheme.panel)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(AppTheme.line.opacity(selectedMode == mode ? 0 : 0.76), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var workflowSection: some View {
        VStack(spacing: 16) {
            workflowProgressCard

            AppInfoCard(title: "合同 / 报价 / 收据 / 发票", subtitle: "从报价到签约、收款、开票全部串起来。") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(BusinessDocumentKind.allCases) { kind in
                        Button {
                            editingDocument = store.makeSuggestedDocument(kind: kind, bookingID: effectiveBookingID, clientID: effectiveClientID)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: kind.symbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.accent.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(kind.title)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(kind.suggestedNextKind == nil ? "补齐闭环末端" : "可继续串到下一步")
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .appCardSurface(fillColor: AppTheme.panelStrong)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if scopedDocuments.isEmpty {
                AppEmptyState(title: "还没有业务文档", subtitle: "可以直接从上面的按钮生成报价、合同、收据或发票。", systemImage: "doc.text.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else {
                ForEach(scopedDocuments) { document in
                    documentCard(document)
                }
            }
        }
    }

    private var workflowProgressCard: some View {
        let progress = Double(completedWorkflowStepCount) / Double(BusinessDocumentKind.allCases.count)

        return GlassCard(title: "闭环进度", subtitle: nextWorkflowKind.map { "下一步建议补齐：\($0.title)" } ?? "报价、合同、收据和发票都已经进入流程。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(completedWorkflowStepCount) / \(BusinessDocumentKind.allCases.count)")
                        .font(AppTypography.dataCompact)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(nextWorkflowKind?.title ?? "已闭环")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                ProgressView(value: progress)
                    .tint(AppTheme.accent)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(BusinessDocumentKind.allCases) { kind in
                        workflowStepTile(kind)
                    }
                }
            }
        }
    }

    private func workflowStepTile(_ kind: BusinessDocumentKind) -> some View {
        let document = latestWorkflowDocumentsByKind[kind]
        let statusText = document?.status.title ?? "待创建"
        let isReady = document.map { $0.status != .draft && $0.status != .voided } ?? false

        return Button {
            editingDocument = document ?? store.makeSuggestedDocument(kind: kind, bookingID: effectiveBookingID, clientID: effectiveClientID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isReady ? "checkmark.seal.fill" : kind.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isReady ? AppTheme.accent : AppTheme.secondaryInk)
                    .frame(width: 28, height: 28)
                    .background((isReady ? AppTheme.accent : AppTheme.secondaryInk).opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(statusText)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .appCardSurface(fillColor: AppTheme.panelStrong)
        }
        .buttonStyle(.plain)
    }

    private func documentCard(_ document: BusinessDocumentRecord) -> some View {
        let booking = document.bookingID.flatMap { store.booking(id: $0) }
        let client = document.clientID.flatMap { store.client(id: $0) }
        let shareText = BusinessDocumentTextRenderer.text(
            for: document,
            booking: booking,
            client: client,
            studioProfile: store.resolvedStudioProfile
        )

        return GlassCard(title: document.title, subtitle: document.lifecycleHeadline) {
            HStack(spacing: 10) {
                Label(document.kind.title, systemImage: document.kind.symbolName)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                Spacer()
                Text(document.status.title)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            AppKeyValueRow(title: "编号", value: document.number)
            AppKeyValueRow(title: "总额", value: AppFormatters.currency(document.totalAmount))
            if let client {
                AppKeyValueRow(title: "客户", value: client.name)
            }
            if let booking {
                AppKeyValueRow(title: "订单", value: booking.title)
            }
            if let dueDate = document.dueDate {
                AppKeyValueRow(title: "到期", value: AppFormatters.fullDate(dueDate))
            }
            if document.lineItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("明细")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    ForEach(document.lineItems) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                                if item.detailsText.isEmpty == false {
                                    Text(item.detailsText)
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                            }
                            Spacer()
                            Text(AppFormatters.currency(item.lineTotal))
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("编辑") {
                    editingDocument = document
                }
                .buttonStyle(AppSecondaryButtonStyle())

                ShareLink(item: shareText) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                if let nextKind = document.kind.suggestedNextKind {
                    Button("生成\(nextKind.title)") {
                        var draft = store.makeSuggestedDocument(kind: nextKind, bookingID: document.bookingID, clientID: document.clientID)
                        draft.linkedDocumentID = document.id
                        editingDocument = draft
                    }
                    .buttonStyle(AppGhostButtonStyle())
                }
                Button("复制文案") {
                    UIPasteboard.general.string = shareText
                    store.markDocumentShared(document.id)
                    alertMessage = "已复制到剪贴板。"
                }
                .buttonStyle(AppGhostButtonStyle())
            }
        }
    }

    private var assetsSection: some View {
        VStack(spacing: 16) {
            AppInfoCard(title: "附件与参考资料管理", subtitle: "支持本地文件、参考链接、合同附件、交付素材。") {
                HStack(spacing: 10) {
                    Button {
                        pendingImportCategory = .reference
                        presentingFileImporter = true
                    } label: {
                        Label("导入文件", systemImage: "square.and.arrow.down.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())

                    Button {
                        editingAttachment = AttachmentRecord(
                            bookingID: effectiveBookingID,
                            clientID: effectiveClientID,
                            category: .reference,
                            title: "",
                            externalURLString: "https://"
                        )
                    } label: {
                        Label("添加链接", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }

                AppInlineNote(systemImage: "paperclip", text: "文件导入后会复制到 App 本地资料库；链接类资料会直接保留外部 URL。")
            }

            if scopedAttachments.isEmpty {
                AppEmptyState(title: "还没有资料", subtitle: "可以导入参考图、合同附件、发票扫描件、场地资料或交付素材。", systemImage: "paperclip.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else {
                ForEach(scopedAttachments) { attachment in
                    attachmentCard(attachment)
                }
            }
        }
    }

    private func attachmentCard(_ attachment: AttachmentRecord) -> some View {
        let localURL = store.attachmentFileURL(for: attachment)
        return GlassCard(title: attachment.title, subtitle: attachment.category.title) {
            if attachment.note.isEmpty == false {
                Text(attachment.note)
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            HStack(spacing: 12) {
                AppMetricTile(title: "来源", value: attachment.isExternalLink ? "外部链接" : "本地文件", subtitle: attachment.mimeType, fillColor: AppTheme.panelStrong)
                AppMetricTile(title: "大小", value: attachment.byteCount > 0 ? ByteCountFormatter.string(fromByteCount: attachment.byteCount, countStyle: .file) : "—", subtitle: AppFormatters.relativeDate(attachment.updatedAt), fillColor: AppTheme.panelStrong)
            }

            if let availabilityMessage = store.attachmentAvailabilityMessage(for: attachment) {
                AppInlineNote(systemImage: "externaldrive.badge.exclamationmark", text: availabilityMessage)
            }

            HStack(spacing: 10) {
                Button("编辑") {
                    editingAttachment = attachment
                }
                .buttonStyle(AppSecondaryButtonStyle())

                if let localURL {
                    ShareLink(item: localURL) {
                        Label("分享文件", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                } else if let linkURL = attachment.preferredOpenURL {
                    Link(destination: linkURL) {
                        Label("打开链接", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
    }

    private var collaborationSection: some View {
        VStack(spacing: 16) {
            AppInfoCard(title: "团队权限与操作留痕", subtitle: "当前正式版提供角色匹配、本地权限和关键操作记录，不再误导为“多人实时协作”。") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AppMetricTile(title: "当前角色", value: store.currentWorkspaceRole.title, subtitle: "按账号 ID / 邮箱自动匹配")
                    AppMetricTile(title: "协作成员", value: "\(store.activeWorkspaceMembers.count)", subtitle: "本地权限工作区")
                    AppMetricTile(title: "资料上传", value: store.collaborationSettings.allowAttachmentUploadByPhotographers ? "摄影师可上传" : "仅管理角色可上传", subtitle: "已接入真实权限判断")
                    AppMetricTile(title: "近期留痕", value: "\(store.collaborationActivities.prefix(20).count)", subtitle: "客户 / 订单 / 文档 / 附件")
                }
            }

            GlassCard(title: "团队策略", subtitle: "保留当前 UI，不改变单人工作流；只展示已真实生效的策略。") {
                Toggle("摄影师允许上传资料", isOn: collaborationBinding(\.allowAttachmentUploadByPhotographers))
                Toggle("只读角色允许导出", isOn: collaborationBinding(\.allowViewerExport))
                AppInlineNote(systemImage: "person.2", text: "在线状态看板、财务审批与真正的多人实时协同尚未接入服务端，因此本版不再对外宣称。")
            }

            GlassCard(title: "成员与权限", subtitle: "支持 Owner / Admin / Producer / Photographer / Finance / Viewer 六种角色。") {
                Button {
                    editingMember = WorkspaceMemberRecord(displayName: "", email: "", role: .producer)
                } label: {
                    Label("新增协作成员", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())

                if store.activeWorkspaceMembers.isEmpty {
                    AppInlineNote(systemImage: "person.2.slash", text: "当前还没有团队成员，单人模式下默认拥有所有权限。")
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.activeWorkspaceMembers) { member in
                            Button {
                                editingMember = member
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                        .overlay {
                                            Text(String(member.displayName.prefix(1)))
                                                .font(AppTypography.bodyStrong)
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.displayName)
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppTheme.ink)
                                        Text(member.email.isEmpty ? member.status.title : member.email)
                                            .font(AppTypography.meta)
                                            .foregroundStyle(AppTheme.secondaryInk)
                                    }
                                    Spacer()
                                    Text(member.role.title)
                                        .font(AppTypography.meta.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .appCardSurface(fillColor: AppTheme.panelStrong)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            GlassCard(title: "当前角色权限", subtitle: "下面列出你现在能做什么。") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(WorkspacePermission.allCases) { permission in
                        HStack(spacing: 10) {
                            Image(systemName: store.canCurrentUserPerform(permission) ? "checkmark.seal.fill" : "lock.fill")
                                .foregroundStyle(store.canCurrentUserPerform(permission) ? AppTheme.accent : AppTheme.secondaryInk)
                            Text(permission.title)
                                .font(AppTypography.body)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                        }
                    }
                }
            }

            GlassCard(title: "协作操作留痕", subtitle: "任何关键动作都会被记录，方便回溯责任与进度。") {
                if store.collaborationActivities.isEmpty {
                    AppInlineNote(systemImage: "clock.badge.questionmark", text: "当前还没有协作操作记录。")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(store.collaborationActivities.prefix(20))) { activity in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(activity.actionTitle)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    Text(AppFormatters.relativeDate(activity.createdAt))
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                Text("\(activity.actorDisplayName) · \(activity.summary)")
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .appCardSurface(fillColor: AppTheme.panelStrong)
                        }
                    }
                }
            }
        }
    }

    private var analyticsSection: some View {
        let dashboard = store.analyticsDashboard
        return VStack(spacing: 16) {
            AppInfoCard(title: "经营分析报表中心", subtitle: "签约额、回款、待收、客单价、复购率、来源与品类一站看完。") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AppMetricTile(title: "总签约额", value: AppFormatters.currency(dashboard.totalBookedAmount), subtitle: "当前工作区所有订单")
                    AppMetricTile(title: "总回款", value: AppFormatters.currency(dashboard.totalCollectedAmount), subtitle: "按付款流水统计")
                    AppMetricTile(title: "待收", value: AppFormatters.currency(dashboard.totalOutstandingAmount), subtitle: "未到拍摄日与逾期待收都计入")
                    AppMetricTile(title: "客单价", value: AppFormatters.currency(dashboard.averageTicketAmount), subtitle: "按有效订单均值")
                    AppMetricTile(title: "复购率", value: percentText(dashboard.repeatClientRate), subtitle: "至少下单 2 次的客户占比")
                    AppMetricTile(title: "留存客户", value: "\(dashboard.retentionClientCount)", subtitle: "客户阶段为“留存 / 老客”")
                }
            }

            if dashboard.revenueTrend.isEmpty == false {
                GlassCard(title: "近 6 个月签约额与回款走势") {
                    Chart(dashboard.revenueTrend) { point in
                        LineMark(
                            x: .value("月份", point.monthStart, unit: .month),
                            y: .value("签约额", point.bookedAmount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.accent)

                        LineMark(
                            x: .value("月份", point.monthStart, unit: .month),
                            y: .value("回款", point.collectedAmount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.info)
                    }
                    .frame(height: 220)
                }
            }

            if dashboard.categoryBreakdown.isEmpty == false {
                GlassCard(title: "品类收入结构") {
                    Chart(dashboard.categoryBreakdown.prefix(8)) { point in
                        BarMark(
                            x: .value("收入", point.bookedAmount),
                            y: .value("品类", point.category.title)
                        )
                        .foregroundStyle(AppTheme.accent)
                    }
                    .frame(height: CGFloat(max(220, dashboard.categoryBreakdown.prefix(8).count * 36)))
                }
            }

            if dashboard.agingBuckets.isEmpty == false {
                GlassCard(title: "待收账龄") {
                    Chart(dashboard.agingBuckets) { bucket in
                        BarMark(
                            x: .value("账龄", bucket.title),
                            y: .value("金额", bucket.amount)
                        )
                        .foregroundStyle(AppTheme.warning)
                    }
                    .frame(height: 220)

                    VStack(spacing: 10) {
                        ForEach(dashboard.agingBuckets) { bucket in
                            AppKeyValueRow(title: bucket.title, value: "\(AppFormatters.currency(bucket.amount)) · \(bucket.bookingCount) 单")
                        }
                    }
                }
            }

            if dashboard.sourceBreakdown.isEmpty == false {
                GlassCard(title: "来源渠道表现", subtitle: "看哪个渠道真的能带来签约。") {
                    VStack(spacing: 10) {
                        ForEach(dashboard.sourceBreakdown.prefix(10)) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.sourceChannel)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(item.clientCount) 位客户")
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                Spacer()
                                Text(AppFormatters.currency(item.bookedAmount))
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .appCardSurface(fillColor: AppTheme.panelStrong)
                        }
                    }
                }
            }
        }
    }

    private var allowedImportTypes: [UTType] {
        #if canImport(UniformTypeIdentifiers)
        return [.item]
        #else
        return []
        #endif
    }

    private func collaborationBinding(_ keyPath: WritableKeyPath<WorkspaceCollaborationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.collaborationSettings[keyPath: keyPath] },
            set: { newValue in
                var updated = store.collaborationSettings
                updated[keyPath: keyPath] = newValue
                store.updateCollaborationSettings(updated)
            }
        )
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let sourceURL = urls.first else { return }
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let attachment = try store.importAttachment(
                    from: sourceURL,
                    bookingID: effectiveBookingID,
                    clientID: effectiveClientID,
                    category: pendingImportCategory,
                    title: sourceURL.deletingPathExtension().lastPathComponent
                )
                editingAttachment = attachment
            } catch {
                alertMessage = error.localizedDescription
            }
        case let .failure(error):
            alertMessage = error.localizedDescription
        }
    }

    private func percentText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

private struct BusinessDocumentEditorView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BusinessDocumentRecord
    let relatedBooking: BookingRecord?
    let relatedClient: ClientRecord?

    init(initialDocument: BusinessDocumentRecord, relatedBooking: BookingRecord?, relatedClient: ClientRecord?) {
        _draft = State(initialValue: initialDocument)
        self.relatedBooking = relatedBooking
        self.relatedClient = relatedClient
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GlassCard(title: draft.kind.title, subtitle: "在不改变整体 UI 的前提下，把业务闭环真正落到单据层。") {
                        Picker("状态", selection: $draft.status) {
                            ForEach(BusinessDocumentStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)

                        AppLabeledField(title: "单号") {
                            TextField("自动生成或手动填写", text: $draft.number)
                                .textInputAutocapitalization(.never)
                        }
                        AppLabeledField(title: "标题") {
                            TextField("文档标题", text: $draft.title)
                        }
                        AppLabeledField(title: "客户 / 抬头") {
                            TextField("客户名称或公司抬头", text: $draft.recipientName)
                        }
                        DatePicker("签发日期", selection: $draft.issueDate, displayedComponents: .date)
                        DatePicker("到期日期", selection: Binding(
                            get: { draft.dueDate ?? draft.issueDate },
                            set: { draft.dueDate = $0 }
                        ), displayedComponents: .date)
                    }

                    GlassCard(title: "明细项目", subtitle: relatedBooking?.title ?? relatedClient?.name) {
                        ForEach($draft.lineItems) { $item in
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("项目名称", text: $item.title)
                                    .textFieldStyle(.roundedBorder)
                                TextField("项目说明", text: $item.detailsText, axis: .vertical)
                                    .lineLimit(2, reservesSpace: true)
                                    .textFieldStyle(.roundedBorder)
                                HStack(spacing: 12) {
                                    TextField("数量", value: $item.quantity, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("单价", value: $item.unitPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Spacer()
                                    Text(AppFormatters.currency(item.lineTotal))
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                }
                            }
                            .padding(.bottom, 6)
                        }

                        Button {
                            draft.lineItems.append(BusinessDocumentLineItem(title: "新增项目", unitPrice: 0))
                        } label: {
                            Label("添加项目", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }

                    GlassCard(title: "金额与条款") {
                        AppLabeledField(title: "优惠金额") {
                            TextField("0", value: $draft.discountAmount, format: .number)
                                .keyboardType(.decimalPad)
                        }
                        AppLabeledField(title: "税率") {
                            TextField("0.06", value: $draft.taxRate, format: .number)
                                .keyboardType(.decimalPad)
                        }
                        AppKeyValueRow(title: "小计", value: AppFormatters.currency(draft.subtotalAmount))
                        AppKeyValueRow(title: "税费", value: AppFormatters.currency(draft.taxAmount))
                        AppKeyValueRow(title: "总计", value: AppFormatters.currency(draft.totalAmount))
                        TextField("备注", text: $draft.notesText, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .textFieldStyle(.roundedBorder)
                        TextField("条款", text: $draft.termsText, axis: .vertical)
                            .lineLimit(5, reservesSpace: true)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(draft.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.upsert(document: draft)
                        dismiss()
                    }
                    .font(AppTypography.bodyStrong)
                }
            }
        }
    }
}

private struct AttachmentEditorView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AttachmentRecord

    init(initialAttachment: AttachmentRecord) {
        _draft = State(initialValue: initialAttachment)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GlassCard(title: "资料信息", subtitle: "可以同时管理本地文件和外部参考链接。") {
                        Picker("分类", selection: $draft.category) {
                            ForEach(AttachmentCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        AppLabeledField(title: "标题") {
                            TextField("资料名称", text: $draft.title)
                        }
                        AppLabeledField(title: "外部链接") {
                            TextField("https://", text: $draft.externalURLString)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                        }
                        TextField("说明", text: $draft.note, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("资料编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.upsert(attachment: draft)
                        dismiss()
                    }
                    .font(AppTypography.bodyStrong)
                }
            }
        }
    }
}

private struct WorkspaceMemberEditorView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WorkspaceMemberRecord

    init(initialMember: WorkspaceMemberRecord) {
        _draft = State(initialValue: initialMember)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GlassCard(title: "成员信息", subtitle: "通过账号 ID / 邮箱自动匹配成员身份。") {
                        AppLabeledField(title: "姓名") {
                            TextField("成员姓名", text: $draft.displayName)
                        }
                        AppLabeledField(title: "邮箱") {
                            TextField("name@example.com", text: $draft.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                        }
                        Picker("角色", selection: $draft.role) {
                            ForEach(WorkspaceRole.allCases) { role in
                                Text(role.title).tag(role)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("状态", selection: $draft.status) {
                            ForEach(WorkspaceMemberStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                        TextField("备注", text: $draft.notesText, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("成员权限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.upsert(workspaceMember: draft)
                        dismiss()
                    }
                    .font(AppTypography.bodyStrong)
                }
            }
        }
    }
}

private struct AppLabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            content
                .textFieldStyle(.roundedBorder)
        }
    }
}
