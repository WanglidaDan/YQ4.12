import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store
    @AppStorage("hasEnteredGuestMode") private var hasEnteredGuestMode = false

    private let showsCloseButton: Bool

    @State private var draftSettings: AppSettings
    @State private var draftStudioProfile: StudioProfile
    @State private var shareURL: URL?
    @State private var fileImportError: String?
    @State private var exportError: String?
    @State private var showingRestoreImporter = false
    @State private var confirmingClearData = false
    @State private var confirmingSignOut = false
    @State private var confirmingDeleteAccount = false
    @State private var showingNewCrewMember = false
    @State private var editingCrewMember: CrewMemberRecord?
    @State private var confirmingArchiveCrewMember: CrewMemberRecord?
    @State private var settingsToastMessage: String?

    init(store: StudioStore? = nil, showsCloseButton: Bool = true) {
        self.showsCloseButton = showsCloseButton
        _draftSettings = State(initialValue: store?.settings ?? .default)
        _draftStudioProfile = State(initialValue: store?.studioProfile ?? .empty)
    }

    var body: some View {
        List {
            Section {
                settingsRouteLink("工作区与团队", systemImage: "person.3") {
                    workspaceLandingPage
                }
                settingsRouteLink("业务偏好", systemImage: "slider.horizontal.3") {
                    businessPreferencesLandingPage
                }
            }

            Section {
                settingsRouteLink("账号与同步", systemImage: "person.crop.circle") {
                    accountLandingPage
                }
                settingsRouteLink("数据与支持", systemImage: "externaldrive") {
                    dataSupportLandingPage
                }
            }

            if let persistenceIssueDescription {
                Section {
                    Label(persistenceIssueDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            if let settingsToastMessage {
                AppToast(message: settingsToastMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if $0 == false { shareURL = nil } })) {
            if let shareURL { ShareSheetView(activityItems: [shareURL]) }
        }
        .sheet(isPresented: $showingNewCrewMember) {
            TeamMemberEditorView()
                .environment(store)
        }
        .sheet(item: $editingCrewMember) { member in
            TeamMemberEditorView(member: member)
                .environment(store)
        }
        .fileImporter(isPresented: $showingRestoreImporter, allowedContentTypes: [.json, .folder], allowsMultipleSelection: false) { result in
            handleRestore(result)
        }
        .confirmationDialog("确认清空当前工作区？", isPresented: $confirmingClearData) {
            Button("清空工作区", role: .destructive) {
                store.clearAllData()
                AppHaptics.success()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(clearWorkspaceMessage)
        }
        .confirmationDialog("确认退出登录？", isPresented: $confirmingSignOut) {
            Button("退出登录", role: .destructive) {
                store.clearAuthProfile()
                hasEnteredGuestMode = false
                AppHaptics.success()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后会回到登录页；当前设备上的本地工作区会保留，但 iCloud 同步会关闭。之后若使用不同账号登录，应用会自动切换到隔离的新工作区，避免误把旧数据同步到新的账户。")
        }
        .confirmationDialog("确认删除账号与当前工作区？", isPresented: $confirmingDeleteAccount) {
            Button("删除", role: .destructive) {
                store.deleteAccountAndWorkspace()
                hasEnteredGuestMode = false
                AppHaptics.success()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会清空当前设备上的工作区数据，并尝试清空你已开启 iCloud 同步的轻量工作区快照。适用于没有独立服务端账号、仅使用当前登录身份识别工作区的版本。")
        }
        .confirmationDialog(
            "确认停用团队成员？",
            isPresented: Binding(
                get: { confirmingArchiveCrewMember != nil },
                set: { if $0 == false { confirmingArchiveCrewMember = nil } }
            )
        ) {
            Button("停用成员", role: .destructive) {
                if let confirmingArchiveCrewMember {
                    store.archiveCrewMember(confirmingArchiveCrewMember.id)
                    if draftSettings.currentCrewMemberID == confirmingArchiveCrewMember.id {
                        draftSettings.currentCrewMemberID = nil
                    }
                    AppHaptics.success()
                }
                confirmingArchiveCrewMember = nil
            }
            Button("取消", role: .cancel) {
                confirmingArchiveCrewMember = nil
            }
        } message: {
            Text("停用后不会再出现在新订单分工选择里，历史订单中的姓名仍会保留。")
        }
        .alert("操作失败", isPresented: Binding(get: { fileImportError != nil || exportError != nil }, set: { if $0 == false { fileImportError = nil; exportError = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(fileImportError ?? exportError ?? "")
        }
        .onAppear {
            draftSettings = store.settings
            draftStudioProfile = store.resolvedStudioProfile
        }
    }

    private func settingsRouteLink<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var workspaceLandingPage: some View {
        AppPageScaffold(title: "工作区与团队", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
            settingsCard(title: "当前工作区", subtitle: workspaceDisplayName) {
                infoRow(title: "账号", value: accountSubtitle)
                infoRow(title: "团队成员", value: "\(store.activeCrewMembers.count) 位启用")
                infoRow(title: "当前成员", value: currentMemberSummary)
            }

            GlassCard(title: "资料与成员") {
                VStack(spacing: 10) {
                    settingsNavigationRow(
                        title: "工作室资料",
                        subtitle: studioProfileSummary,
                        systemImage: "square.and.pencil",
                        tint: AppTheme.accent
                    ) {
                        detailPage(title: "工作室资料") {
                            studioProfileSection
                        }
                    }

                    settingsNavigationRow(
                        title: "个人与工作模式",
                        subtitle: draftSettings.studioModeEnabled ? "团队分工已启用" : "当前为个人工作流",
                        systemImage: "person.text.rectangle.fill",
                        tint: AppTheme.info
                    ) {
                        detailPage(title: "工作模式") {
                            workspaceSection
                        }
                    }

                    settingsNavigationRow(
                        title: "团队成员",
                        subtitle: "\(store.activeCrewMembers.count) 位启用，\(archivedCrewMembers.count) 位停用",
                        systemImage: "person.3.fill",
                        tint: AppTheme.accentWarmDeep
                    ) {
                        crewMembersManagementPage
                    }
                }
            }
        }
    }

    private var businessPreferencesLandingPage: some View {
        AppPageScaffold(title: "业务偏好", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
            settingsCard(title: "当前默认值") {
                infoRow(title: "主题", value: draftSettings.themeStyle.title)
                infoRow(title: "币种", value: draftSettings.currencyCode)
                infoRow(title: "定金比例", value: AppFormatters.percent(draftSettings.defaultDepositRatio))
                infoRow(title: "提醒", value: draftSettings.notificationsEnabled ? "每天 \(draftSettings.defaultReminderHour):00" : "已关闭")
            }

            GlassCard(title: "业务设置") {
                VStack(spacing: 10) {
                    settingsNavigationRow(
                        title: "外观与主题",
                        subtitle: draftSettings.themeStyle.title,
                        systemImage: "paintpalette.fill",
                        tint: AppTheme.accent
                    ) {
                        detailPage(title: "外观与主题") {
                            appearanceSection
                        }
                    }

                    settingsNavigationRow(
                        title: "订单默认值",
                        subtitle: defaultBusinessSummary,
                        systemImage: "doc.text.fill",
                        tint: AppTheme.info
                    ) {
                        detailPage(title: "订单默认值") {
                            businessDefaultsSection
                        }
                    }

                    settingsNavigationRow(
                        title: "提醒规则",
                        subtitle: draftSettings.notificationsEnabled ? "回款与跟进提醒可用" : "提醒已关闭",
                        systemImage: "bell.badge.fill",
                        tint: AppTheme.accentWarmDeep
                    ) {
                        detailPage(title: "提醒规则") {
                            notificationSection
                        }
                    }
                }
            }
        }
    }

    private var accountLandingPage: some View {
        detailPage(title: "账号与同步") {
            accountSection
        }
    }

    private var dataSupportLandingPage: some View {
        AppPageScaffold(title: "数据与支持", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
            GlassCard(title: "数据工具") {
                VStack(spacing: 10) {
                    settingsNavigationRow(
                        title: "备份与恢复",
                        subtitle: "JSON、CSV、完整备份",
                        systemImage: "externaldrive.badge.timemachine",
                        tint: AppTheme.accent
                    ) {
                        detailPage(title: "备份与恢复") {
                            dataSection
                        }
                    }

                    settingsNavigationRow(
                        title: "关于与支持",
                        subtitle: appVersionText,
                        systemImage: "questionmark.circle.fill",
                        tint: AppTheme.info
                    ) {
                        detailPage(title: "关于与支持") {
                            supportSection
                        }
                    }
                }
            }
        }
    }

    private var crewMembersManagementPage: some View {
        AppPageScaffold(title: "团队成员", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
            settingsCard(title: "成员管理") {
                Button {
                    showingNewCrewMember = true
                    AppHaptics.tapLight()
                } label: {
                    Label("新增团队成员", systemImage: "plus.circle.fill")
                }
                .buttonStyle(AppPrimaryButtonStyle())

                if store.activeCrewMembers.isEmpty {
                    AppInlineNote(systemImage: "person.crop.circle.badge.plus", text: "还没有启用成员，新增后可直接用于订单分工。", tint: AppTheme.accent)
                } else {
                    subsectionTitle("启用成员")
                    ForEach(store.activeCrewMembers) { member in
                        crewMemberManagementRow(member, isArchived: false)
                    }
                }

                if archivedCrewMembers.isEmpty == false {
                    minorSeparator
                    subsectionTitle("停用成员")
                    ForEach(archivedCrewMembers) { member in
                        crewMemberManagementRow(member, isArchived: true)
                    }
                }
            }
        }
    }

    private func crewMemberManagementRow(_ member: CrewMemberRecord, isArchived: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill((isArchived ? AppTheme.secondaryInk : AppTheme.accent).opacity(0.12))
                    .frame(width: 42, height: 42)
                Text(memberInitial(member))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(isArchived ? AppTheme.secondaryInk : AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(memberSubtitle(member, isArchived: isArchived))
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Menu {
                if isArchived {
                    Button("恢复成员", systemImage: "arrow.uturn.backward.circle") {
                        store.restoreCrewMember(member.id)
                        AppHaptics.success()
                    }
                } else {
                    Button("编辑", systemImage: "pencil") {
                        editingCrewMember = member
                    }
                    Button("停用", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                        confirmingArchiveCrewMember = member
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.52), lineWidth: 1)
        }
    }

    private func settingsNavigationRow<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.54), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var workspaceDisplayName: String {
        let name = draftStudioProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "影期工作区" : name
    }

    private var studioProfileSummary: String {
        let city = draftStudioProfile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = draftStudioProfile.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if city.isEmpty == false && phone.isEmpty == false {
            return "\(city) · \(phone)"
        }
        if city.isEmpty == false { return city }
        if phone.isEmpty == false { return phone }
        return "补全名称、电话、城市和地址"
    }

    private var currentMemberSummary: String {
        if let memberID = draftSettings.currentCrewMemberID,
           let member = store.crewMember(id: memberID),
           member.isArchived == false {
            return member.displayName
        }
        let name = draftSettings.currentMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty == false { return name }
        return "未选择"
    }

    private var defaultBusinessSummary: String {
        let location = draftSettings.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let deposit = AppFormatters.percent(draftSettings.defaultDepositRatio)
        return location.isEmpty ? "\(draftSettings.currencyCode) · 定金 \(deposit)" : "\(location) · 定金 \(deposit)"
    }

    private var archivedCrewMembers: [CrewMemberRecord] {
        store.crewMembers
            .filter(\.isArchived)
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func memberInitial(_ member: CrewMemberRecord) -> String {
        let trimmed = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0) } ?? "成"
    }

    private func memberSubtitle(_ member: CrewMemberRecord, isArchived: Bool) -> String {
        var parts: [String] = []
        if member.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(member.roleTitle)
        }
        if member.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(member.phone)
        } else if member.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(member.email)
        }
        if isArchived {
            parts.append("已停用")
        }
        return parts.isEmpty ? "未填写角色和联系方式" : parts.joined(separator: " · ")
    }

    private var workspaceSection: some View {
        settingsCard {
            settingsToggleRow(title: "成员协作", subtitle: "开启后可以把拍摄任务分配给不同成员。", isOn: $draftSettings.studioModeEnabled)

            settingsToggleRow(title: "高亮我的分工", subtitle: "在工作台优先显示属于我的安排。", isOn: $draftSettings.crewLensEnabled)
                .disabled(draftSettings.studioModeEnabled == false)

            settingsPickerRow(title: "当前成员") {
                Picker("当前成员", selection: $draftSettings.currentCrewMemberID) {
                    Text("未选择").tag(Optional<UUID>.none)
                    ForEach(store.activeCrewMembers) { member in
                        Text(member.displayName).tag(Optional(member.id))
                    }
                }
                .pickerStyle(.menu)
            }

            settingsTextField(title: "临时成员名", text: $draftSettings.currentMemberName, prompt: "兼容旧数据或临时身份")
                .disabled(draftSettings.studioModeEnabled == false)
        }
    }

    private var studioProfileSection: some View {
        settingsCard {
            settingsTextField(title: "工作室名称", text: $draftStudioProfile.displayName, prompt: "例如 影期摄影工作室")
            settingsTextField(title: "公司主体", text: $draftStudioProfile.legalName, prompt: "用于合同或发票抬头")
            settingsTextField(title: "联系电话", text: $draftStudioProfile.contactPhone, prompt: "用于客户联络")
                .keyboardType(.phonePad)
            settingsTextField(title: "联系邮箱", text: $draftStudioProfile.contactEmail, prompt: "用于业务往来")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            settingsTextField(title: "所在城市", text: $draftStudioProfile.city, prompt: "例如 上海")
            settingsTextField(title: "详细地址", text: $draftStudioProfile.address, prompt: "用于合同与定位说明")
            settingsTextEditor(title: "备注", text: $draftStudioProfile.notes, prompt: "补充品牌或业务说明")
        }
    }

    private var appearanceSection: some View {
        settingsCard {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppThemeStyle.allCases) { style in
                        Button {
                            draftSettings.themeStyle = style
                            AppHaptics.tapLight()
                        } label: {
                            ThemeStyleCard(style: style, isSelected: draftSettings.themeStyle == style)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var businessDefaultsSection: some View {
        settingsCard {
            settingsTextField(title: "默认拍摄地点", text: $draftSettings.defaultLocation, prompt: "新建档期时自动带出")
            settingsTextEditor(title: "默认备注", text: $draftSettings.defaultNotes, prompt: "常用交付、流程或补充说明")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("默认定金比例")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(AppFormatters.percent(draftSettings.defaultDepositRatio))
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Slider(value: $draftSettings.defaultDepositRatio, in: 0...1, step: 0.05)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

            settingsPickerRow(title: "工作区币种") {
                Picker("工作区币种", selection: $draftSettings.currencyCode) {
                    ForEach(AppSettings.supportedCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.menu)
            }

            settingsTextField(title: "默认尾款规则", text: $draftSettings.defaultBalanceRule, prompt: "例如 拍摄当天付清尾款")
        }
    }

    private var notificationSection: some View {
        settingsCard {
            settingsToggleRow(title: "开启提醒", subtitle: "统一控制订单与跟进提醒。", isOn: $draftSettings.notificationsEnabled)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认提醒时间")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text("每天 \(draftSettings.defaultReminderHour):00 推送提醒")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer(minLength: 0)
                Stepper("", value: $draftSettings.defaultReminderHour, in: 0...23)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

            settingsToggleRow(title: "提醒待回款", subtitle: "针对尚未完成的付款计划。", isOn: $draftSettings.remindOutstandingPayments)
            settingsToggleRow(title: "提醒待跟进", subtitle: "针对临近或逾期的客户跟进。", isOn: $draftSettings.remindFollowUps)
        }
    }

    private var accountSection: some View {
        settingsCard {
            if let authProfile = store.authProfile {
                infoRow(title: "当前登录账号", value: authProfile.fullName ?? authProfile.email ?? "已登录")
                settingsToggleRow(title: "启用 iCloud 同步", subtitle: cloudSyncDescription, isOn: $draftSettings.iCloudSyncEnabled)

                if let persistenceIssue = persistenceIssueDescription {
                    AppInlineNote(systemImage: "exclamationmark.triangle.fill", text: persistenceIssue, tint: .orange)
                }

                Button("退出登录", role: .destructive) {
                    confirmingSignOut = true
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button("删除账号与当前工作区", role: .destructive) {
                    confirmingDeleteAccount = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
            } else {
                infoRow(title: "当前模式", value: "本地工作区")
                AppInlineNote(systemImage: "icloud.slash", text: "未登录时数据只保存在当前设备。需要跨设备同步时，可先返回登录页，再使用账号登录进入。")

                Button("前往登录页") {
                    hasEnteredGuestMode = false
                    dismiss()
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }

    private var dataSection: some View {
        settingsCard {
            actionRow(title: "导出 JSON", subtitle: "用于结构化备份和迁移") { exportJSON() }
            actionRow(title: "导出 CSV", subtitle: "用于表格分析或外部归档") { exportCSV() }
            actionRow(title: "完整备份（含附件）", subtitle: "打包工作区和资料文件") { backup() }
            actionRow(title: "恢复备份", subtitle: "从 JSON 或完整备份目录恢复") { showingRestoreImporter = true }
            actionRow(title: "清空当前工作区", subtitle: "删除客户、档期、跟进与付款记录", role: .destructive) { confirmingClearData = true }
        }
    }

    private var supportSection: some View {
        settingsCard {
            infoRow(title: "App 名称", value: "影期")
            infoRow(title: "版本号", value: appVersionText)
            infoRow(title: "支持邮箱", value: "support@yingqi.app")

            NavigationLink {
                LegalTextView(title: "隐私说明", bodyText: privacyText)
            } label: {
                navigationActionLabel(title: "隐私说明", subtitle: "查看数据与权限说明")
            }
            .buttonStyle(.plain)

            NavigationLink {
                LegalTextView(title: "用户协议", bodyText: termsText)
            } label: {
                navigationActionLabel(title: "用户协议", subtitle: "查看产品使用规则")
            }
            .buttonStyle(.plain)

            if let supportURL = URL(string: "mailto:support@yingqi.app") {
                Link(destination: supportURL) {
                    navigationActionLabel(title: "联系支持", subtitle: "通过邮件反馈问题或建议")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var accountSubtitle: String {
        if let authProfile = store.authProfile {
            return authProfile.fullName ?? authProfile.email ?? "已登录"
        }
        return "本地工作区"
    }

    private func detailPage<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        AppPageScaffold(title: title, titleDisplayMode: .inline) {
            content()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存", systemImage: "checkmark") {
                    saveAll()
                }
                .fontWeight(.semibold)
            }
        }
        .onDisappear {
            saveAll(showFeedback: false)
        }
    }

    private func settingsCard<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subsectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.mutedInk)
            .padding(.top, 2)
    }

    private var minorSeparator: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.6))
            .padding(.vertical, 2)
    }

    private func settingsTextField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func settingsTextEditor(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func settingsPickerRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 0)
            content()
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func infoRow(title: String, value: String) -> some View {
        AppKeyValueRow(title: title, value: value)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func actionRow(title: String, subtitle: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            navigationActionLabel(title: title, subtitle: subtitle, tint: role == .destructive ? .red : AppTheme.ink)
        }
        .buttonStyle(.plain)
    }

    private func navigationActionLabel(title: String, subtitle: String, tint: Color = AppTheme.ink) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func saveAll(showFeedback: Bool = true) {
        var normalizedSettings = draftSettings
        var normalizedProfile = draftStudioProfile

        normalizedProfile.displayName = normalizedProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.legalName = normalizedProfile.legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.contactPhone = AppFormatters.sanitizedPhoneNumber(normalizedProfile.contactPhone)
        normalizedProfile.contactEmail = normalizedProfile.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.city = normalizedProfile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.address = normalizedProfile.address.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.notes = normalizedProfile.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        normalizedSettings.currencyCode = AppSettings.normalizedCurrencyCode(normalizedSettings.currencyCode)
        normalizedSettings.studioName = normalizedProfile.displayName
        normalizedSettings.contactPhone = normalizedProfile.contactPhone

        if store.isAuthenticated == false {
            normalizedSettings.iCloudSyncEnabled = false
        }

        if normalizedSettings.studioModeEnabled == false {
            normalizedSettings.crewLensEnabled = false
            normalizedSettings.currentCrewMemberID = nil
            normalizedSettings.currentMemberName = ""
        } else if normalizedSettings.currentCrewMemberID == nil,
                  normalizedSettings.currentMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            normalizedSettings.currentMemberName = normalizedSettings.currentMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedSettings.crewLensEnabled = true
        }

        if normalizedSettings.currentCrewMemberID != nil {
            normalizedSettings.currentMemberName = ""
        }

        store.updateStudioProfile(normalizedProfile)
        store.updateSettings(normalizedSettings)
        draftSettings = store.settings
        draftStudioProfile = store.resolvedStudioProfile
        if showFeedback {
            AppHaptics.success()
            showSettingsToast("设置已保存")
        }
    }

    private func showSettingsToast(_ message: String) {
        withAnimation(.snappy(duration: 0.2)) {
            settingsToastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy(duration: 0.2)) {
                if settingsToastMessage == message {
                    settingsToastMessage = nil
                }
            }
        }
    }

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var cloudSyncDescription: String {
        if let issue = store.lastSyncIssueMessage, issue.isEmpty == false {
            return issue
        }
        if draftSettings.iCloudSyncEnabled == false {
            return "关闭后只保留本机工作区；开启后会以最近修改的工作区作为同步基准。由于当前方案是轻量同步，建议在大量历史数据时先备份或归档。"
        }
        if CloudSyncService.shared.isAvailable {
            return "当前设备已检测到可用的 iCloud 账户，后续档期、客户、跟进和付款会随保存自动同步。若工作区数据量过大，系统会自动阻止开启轻量同步并给出提示。"
        }
        return "当前设备未检测到可用的 iCloud 账户，开启后也暂时不会同步，请先确认系统 iCloud 状态。"
    }

    private var persistenceIssueDescription: String? {
        let trimmed = store.lastPersistenceIssueMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else { return nil }
        if let issueAt = store.lastPersistenceIssueAt {
            return "最近一次保存异常（\(AppFormatters.fullDate(issueAt)) \(AppFormatters.time(issueAt))）：\n\(trimmed)"
        }
        return trimmed
    }

    private var clearWorkspaceMessage: String {
        if store.settings.iCloudSyncEnabled || draftSettings.iCloudSyncEnabled {
            return "这会清空当前工作区里的客户、档期、跟进与付款记录，并把空工作区同步到同一 Apple 账户下已开启同步的设备。设置、模板和登录状态会保留。"
        }
        return "这会清空当前工作区里的客户、档期、跟进与付款记录。设置、模板和登录状态会保留。"
    }

    private var privacyText: String {
        """
        影期默认优先在本地保存你的档期、客户、跟进、付款、模板和设置数据。

        1. 不登录也可以使用，数据默认保存在本机。
        2. 当你主动使用 Apple 登录时，我们仅保存必要的 Apple 标识信息，用于识别你的工作区身份。
        3. 只有当你在设置页明确开启 iCloud 同步，且设备 iCloud 可用时，数据才会通过你的 Apple 账户在 iCloud 内同步；我们不会将业务数据上传到自有服务器。
        4. 当前版本不提供正式上线的位置或天气能力，也不会在启动时自动请求定位权限。
        5. 你可以在设置页导出、完整备份（含附件）、恢复、清空当前工作区，或删除 Apple 登录与当前工作区；如需隐私支持，请联系 support@yingqi.app。
        """
    }

    private var termsText: String {
        """
        欢迎使用影期。影期是一款面向摄影师、摄影团队与工作室的档期、客户、跟进与收款管理工具。

        1. 你可在本地工作区中记录客户资料、订单信息、跟进事项与付款记录，并对你录入的数据准确性负责。
        2. 影期提供归档、删除、导出、备份与恢复功能；删除属于不可恢复操作，请在执行前确认。
        3. 若你选择使用 Apple 登录或 iCloud 同步，相关数据将通过 Apple 提供的能力在你的设备与账户环境内同步。
        4. 影期不会替你向客户自动作出业务承诺，订单确认、价格、交付与收款规则仍由你自行决定并承担责任。
        5. 如遇到异常，请先做完整备份（含附件），再通过 support@yingqi.app 联系我们。
        """
    }

    private func labeledRow(title: String, value: String) -> some View {
        AppSettingRow(title: title, value: value)
    }

    private func exportJSON() {
        do {
            shareURL = try store.exportJSON()
            AppHaptics.success()
        } catch {
            exportError = "JSON 导出失败，请稍后重试。"
            AppHaptics.error()
        }
    }

    private func exportCSV() {
        do {
            shareURL = try store.exportCSV()
            AppHaptics.success()
        } catch {
            exportError = "CSV 导出失败，请稍后重试。"
            AppHaptics.error()
        }
    }

    private func backup() {
        do {
            shareURL = try store.createBackup()
            AppHaptics.success()
        } catch {
            exportError = "完整备份失败，请稍后重试。"
            AppHaptics.error()
        }
    }

    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let scopedAccessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if scopedAccessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try store.restore(from: url)
                AppHaptics.success()
            } catch {
                fileImportError = "恢复失败，请确认备份文件或完整备份目录格式正确。"
                AppHaptics.error()
            }
        case .failure:
            fileImportError = "未能读取备份文件。"
            AppHaptics.error()
        }
    }
}

struct TeamMemberEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    let member: CrewMemberRecord?

    @State private var displayName: String
    @State private var roleTitle: String
    @State private var phone: String
    @State private var email: String
    @State private var notes: String

    init(member: CrewMemberRecord? = nil) {
        self.member = member
        _displayName = State(initialValue: member?.displayName ?? "")
        _roleTitle = State(initialValue: member?.roleTitle ?? "")
        _phone = State(initialValue: member?.phone ?? "")
        _email = State(initialValue: member?.email ?? "")
        _notes = State(initialValue: member?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成员信息") {
                    TextField("姓名", text: $displayName)
                    TextField("角色", text: $roleTitle)
                    TextField("电话", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(member == nil ? "新增团队成员" : "编辑团队成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let draft = CrewMemberRecord(
                            id: member?.id ?? UUID(),
                            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                            roleTitle: roleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            phone: AppFormatters.sanitizedPhoneNumber(phone),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            isArchived: member?.isArchived ?? false,
                            createdAt: member?.createdAt ?? .now
                        )
                        store.upsert(crewMember: draft)
                        AppHaptics.success()
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LegalTextView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
