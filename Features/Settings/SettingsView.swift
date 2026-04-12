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
    @State private var confirmingImportSampleData = false
    @State private var businessCenterRoute: BusinessCenterRoute?

    init(store: StudioStore? = nil, showsCloseButton: Bool = true) {
        self.showsCloseButton = showsCloseButton
        _draftSettings = State(initialValue: store?.settings ?? .default)
        _draftStudioProfile = State(initialValue: store?.studioProfile ?? .empty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppSettingRow(
                        title: draftStudioProfile.displayName.isEmpty ? "影期工作区" : draftStudioProfile.displayName,
                        value: accountSubtitle
                    )
                    AppSettingRow(title: "团队成员", value: "\(store.activeCrewMembers.count)")
                    AppSettingRow(title: "同步状态", value: draftSettings.iCloudSyncEnabled ? "已开启" : "未开启")
                }

                Section("设置") {
                    NavigationLink {
                        detailPage(title: "工作区") {
                            workspaceHubSection
                        }
                    } label: {
                        AppSettingRow(title: "工作区", value: "身份、资料、团队")
                    }

                    NavigationLink {
                        detailPage(title: "偏好设置") {
                            preferencesSection
                        }
                    } label: {
                        AppSettingRow(title: "偏好设置", value: "主题、默认值、提醒")
                    }

                    NavigationLink {
                        detailPage(title: "账号与同步") {
                            accountSection
                        }
                    } label: {
                        AppSettingRow(title: "账号与同步", value: store.isAuthenticated ? "Apple ID 与 iCloud" : "本地工作区")
                    }

                    NavigationLink {
                        detailPage(title: "工具与支持") {
                            toolsSection
                        }
                    } label: {
                        AppSettingRow(title: "工具与支持", value: "业务、数据、支持")
                    }
                }

                if let persistenceIssueDescription {
                    Section("同步状态") {
                        Text(persistenceIssueDescription)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
            .navigationTitle(showsCloseButton ? "设置" : "我的")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveAll()
                    }
                }
            }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if $0 == false { shareURL = nil } })) {
                if let shareURL { ShareSheetView(activityItems: [shareURL]) }
            }
            .sheet(item: $businessCenterRoute) { route in
                BusinessCenterView(
                    initialMode: route.mode,
                    bookingID: route.bookingID,
                    clientID: route.clientID
                )
                .environment(store)
            }
            .fileImporter(isPresented: $showingRestoreImporter, allowedContentTypes: [.json, .folder], allowsMultipleSelection: false) { result in
                handleRestore(result)
            }
            .confirmationDialog("确认导入示例数据？", isPresented: $confirmingImportSampleData) {
                Button("导入", role: .destructive) {
                    if store.importSampleDataIfEmpty() {
                        AppHaptics.success()
                    } else {
                        fileImportError = "当前工作区已有数据，请先备份并清空当前工作区后再导入示例数据。"
                        AppHaptics.error()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("仅当当前工作区为空时才会导入演示客户、档期和跟进数据。")
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
            .confirmationDialog("确认退出 Apple 登录？", isPresented: $confirmingSignOut) {
                Button("退出登录", role: .destructive) {
                    store.clearAuthProfile()
                    hasEnteredGuestMode = false
                    AppHaptics.success()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后会回到登录页；当前设备上的本地工作区会保留，但 iCloud 同步会关闭。之后若使用不同 Apple ID 登录，应用会自动切换到隔离的新工作区，避免误把旧数据同步到新的账户。")
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
                Text("这会清空当前设备上的工作区数据，并尝试清空你已开启 iCloud 同步的轻量工作区快照。适用于没有独立服务端账号、仅使用 Apple 登录识别身份的当前版本。")
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
    }

    private var workspaceHubSection: some View {
        settingsCard(title: "工作区", subtitle: "工作室资料会用于文档、报价和对外展示。") {
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

    private var preferencesSection: some View {
        settingsCard(title: "偏好设置", subtitle: "外观、业务默认值和提醒放在一处，修改路径更短。") {
            subsectionTitle("外观与主题")
            AppInlineNote(systemImage: "paintpalette.fill", text: "视觉系统已统一为 studio minimal 语法，这里只调整主色倾向。")
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

            minorSeparator

            subsectionTitle("业务默认值")
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

            minorSeparator

            subsectionTitle("提醒与通知")
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

    private var toolsSection: some View {
        settingsCard(title: "工具与支持", subtitle: "业务入口、数据操作和支持信息集中到一个区域。") {
            subsectionTitle("业务中心")
            businessActionRow(title: "合同 / 报价 / 收据 / 发票", subtitle: "生成与管理业务文档", mode: .workflow)
            businessActionRow(title: "外部日历整备", subtitle: "查看订单级日历接入状态", mode: .calendar)
            businessActionRow(title: "附件与参考资料", subtitle: "管理合同附件与交付资料", mode: .assets)
            businessActionRow(title: "经营分析报表", subtitle: "查看收款、成交和经营表现", mode: .analytics)

            minorSeparator

            subsectionTitle("数据管理")
            actionRow(title: "导出 JSON", subtitle: "用于结构化备份和迁移") { exportJSON() }
            actionRow(title: "导出 CSV", subtitle: "用于表格分析或外部归档") { exportCSV() }
            actionRow(title: "完整备份（含附件）", subtitle: "打包工作区和资料文件") { backup() }
            actionRow(title: "恢复备份", subtitle: "从 JSON 或完整备份目录恢复") { showingRestoreImporter = true }
            actionRow(title: "导入示例数据", subtitle: "仅在空工作区中导入演示内容") { confirmingImportSampleData = true }
            actionRow(title: "清空当前工作区", subtitle: "删除客户、档期、跟进与付款记录", role: .destructive) { confirmingClearData = true }

            minorSeparator

            subsectionTitle("关于与支持")
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

    private var workspaceSection: some View {
        settingsCard(title: "个人与工作模式", subtitle: "先定义你是谁，以及工作台如何识别你的分工。") {
            settingsToggleRow(title: "团队模式", subtitle: "开启后可以按成员分配拍摄任务。", isOn: $draftSettings.studioModeEnabled)

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
        settingsCard(title: "工作室信息", subtitle: "这些信息会用于文档、报价和对外展示。") {
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
        settingsCard(title: "外观与主题", subtitle: "保留原有主题能力，改成更清楚的横向选择。") {
            AppInlineNote(systemImage: "paintpalette.fill", text: "视觉系统已统一为 studio minimal 语法，这里只调整主色倾向。")

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
        settingsCard(title: "业务默认值", subtitle: "影响新建档期、收款和业务文案的默认状态。") {
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
        settingsCard(title: "提醒与通知", subtitle: "控制提醒是否开启，以及默认的提醒时段。") {
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
        settingsCard(title: "账号与同步", subtitle: "Apple ID 登录和 iCloud 同步设置。") {
            if let authProfile = store.authProfile {
                infoRow(title: "当前 Apple ID", value: authProfile.fullName ?? authProfile.email ?? "已登录")
                settingsToggleRow(title: "启用 iCloud 同步", subtitle: cloudSyncDescription, isOn: $draftSettings.iCloudSyncEnabled)

                if let persistenceIssue = persistenceIssueDescription {
                    AppInlineNote(systemImage: "exclamationmark.triangle.fill", text: persistenceIssue, tint: .orange)
                }

                Button("退出 Apple 登录", role: .destructive) {
                    confirmingSignOut = true
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button("删除账号与当前工作区", role: .destructive) {
                    confirmingDeleteAccount = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
            } else {
                infoRow(title: "当前模式", value: "本地工作区")
                AppInlineNote(systemImage: "icloud.slash", text: "未登录时数据只保存在当前设备。需要跨设备同步时，可先返回登录页，再使用 Apple ID 进入。")

                Button("前往登录页") {
                    hasEnteredGuestMode = false
                    dismiss()
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }

    private var operationsSection: some View {
        settingsCard(title: "业务中心", subtitle: "保持完整功能，但按业务目的重新分组。") {
            businessActionRow(title: "合同 / 报价 / 收据 / 发票", subtitle: "生成与管理业务文档", mode: .workflow)
            businessActionRow(title: "外部日历整备", subtitle: "查看订单级日历接入状态", mode: .calendar)
            businessActionRow(title: "附件与参考资料", subtitle: "管理合同附件与交付资料", mode: .assets)
            businessActionRow(title: "团队权限与留痕", subtitle: "查看协作角色与关键操作记录", mode: .collaboration)
            businessActionRow(title: "经营分析报表", subtitle: "查看收款、成交和经营表现", mode: .analytics)
        }
    }

    private var dataSection: some View {
        settingsCard(title: "数据管理", subtitle: "导出、备份、恢复和清理当前工作区。") {
            actionRow(title: "导出 JSON", subtitle: "用于结构化备份和迁移") { exportJSON() }
            actionRow(title: "导出 CSV", subtitle: "用于表格分析或外部归档") { exportCSV() }
            actionRow(title: "完整备份（含附件）", subtitle: "打包工作区和资料文件") { backup() }
            actionRow(title: "恢复备份", subtitle: "从 JSON 或完整备份目录恢复") { showingRestoreImporter = true }
            actionRow(title: "导入示例数据", subtitle: "仅在空工作区中导入演示内容") { confirmingImportSampleData = true }
            actionRow(title: "清空当前工作区", subtitle: "删除客户、档期、跟进与付款记录", role: .destructive) { confirmingClearData = true }
        }
    }

    private var supportSection: some View {
        settingsCard(title: "关于与支持", subtitle: "版本信息、隐私协议和联系支持。") {
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
            return authProfile.fullName ?? authProfile.email ?? "Apple ID 已登录"
        }
        return "本地工作区"
    }

    private func detailPage<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
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

    private func businessActionRow(title: String, subtitle: String, mode: BusinessCenterMode) -> some View {
        Button {
            businessCenterRoute = BusinessCenterRoute(mode: mode, bookingID: nil, clientID: nil)
        } label: {
            navigationActionLabel(title: title, subtitle: subtitle)
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

    private func saveAll() {
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
        AppHaptics.success()
        if showsCloseButton { dismiss() }
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
        .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
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
