import SwiftUI

struct ClientEditorView: View {
    private let client: ClientRecord?
    private let onSaved: ((ClientRecord) -> Void)?

    init(client: ClientRecord? = nil, onSaved: ((ClientRecord) -> Void)? = nil) {
        self.client = client
        self.onSaved = onSaved
    }

    var body: some View {
        if let client {
            ClientEditFormView(client: client, onSaved: onSaved)
        } else {
            CreateClientFlowView(onSaved: onSaved)
        }
    }
}

private struct CreateClientFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    let onSaved: ((ClientRecord) -> Void)?

    @State private var name = ""
    @State private var city = ""
    @State private var phoneNumber = ""
    @State private var wechatID = ""
    @State private var emailAddress = ""
    @State private var sourceChannel = ""
    @State private var notesText = ""
    @State private var stage: LeadStage = .discovery
    @State private var stageMode: LeadStageMode = .manual
    @State private var tier: ClientTier = .standard
    @State private var needsFollowUp = false
    @State private var nextContactAt = Date().addingTimeInterval(86_400)
    @State private var showingBusinessFields = false

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "新增客户", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 24) {
                AppCreateHeader(
                    eyebrow: "新增客户",
                    title: resolvedName,
                    subtitle: "姓名、电话、微信都可以先只填一项；没有名称时会自动生成。",
                    systemImage: "person.badge.plus"
                )
                autoNameHint
                essentialsSection
                businessDisclosure
                savePreviewSection
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Label("保存客户", systemImage: "checkmark")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.panelStrong)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.thinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var autoNameHint: some View {
        if trimmedName.isEmpty {
            AppInlineNote(systemImage: "wand.and.stars", text: "未填客户名称时，会保存为“\(resolvedName)”。电话、微信和来源都不是必填。", tint: AppTheme.accent)
        }
    }

    private var essentialsSection: some View {
        Group {
            AppEditorCard(title: "快速资料", subtitle: "只填你现在知道的信息，剩下的以后补。") {
                AppEditorLabeledField("客户名称") {
                    TextField("昵称、公司名或联系人", text: $name)
                }

                AppEditorDivider()

                AppEditorLabeledField("城市 / 区域") {
                    TextField("例如：上海", text: $city)
                }
                AppEditorDivider()
                AppEditorLabeledField("电话") {
                    TextField("手机号", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                AppEditorDivider()

                AppEditorLabeledField("微信") {
                    TextField("微信号", text: $wechatID)
                        .textInputAutocapitalization(.never)
                }

                AppEditorDivider()

                AppEditorLabeledField("邮箱") {
                    TextField("邮箱地址", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
        }
    }

    private var businessDisclosure: some View {
        DisclosureGroup(isExpanded: $showingBusinessFields) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                AppEditorCard(title: "来源与价值") {
                    AppEditorLabeledField("来源渠道") {
                        TextField("小红书 / 转介绍 / 老客户复购", text: $sourceChannel)
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("客户层级") {
                        Picker("客户层级", selection: $tier) {
                            ForEach(ClientTier.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("客户阶段") {
                        Picker("客户阶段", selection: $stage) {
                            ForEach(LeadStage.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }
                }

                AppEditorCard(title: "跟进计划") {
                    Toggle("安排下次跟进", isOn: $needsFollowUp)
                    if needsFollowUp {
                        AppEditorDivider()
                        AppEditorLabeledField("下次跟进") {
                            DatePicker("下次跟进", selection: $nextContactAt)
                                .labelsHidden()
                        }
                    }
                }

                AppEditorCard(title: "备注") {
                    AppEditorLabeledField("客户备注") {
                        TextField("偏好、预算、沟通重点、拍摄风格等", text: $notesText, axis: .vertical)
                            .lineLimit(3...7)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: showingBusinessFields ? "chevron.down.circle.fill" : "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(showingBusinessFields ? "收起经营信息" : "补充来源、层级和跟进")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text("这些内容都可稍后在客户详情里补。")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
            }
            .padding(16)
            .appCardSurface(fillColor: AppTheme.panel)
        }
        .tint(AppTheme.ink)
    }

    private var savePreviewSection: some View {
        AppEditorCard(title: "保存后") {
            AppKeyValueRow(title: "客户", value: trimmedName.isEmpty ? "未填写" : trimmedName)
            AppKeyValueRow(title: "保存名称", value: resolvedName)
            AppKeyValueRow(title: "联系方式", value: contactSummary)
            AppKeyValueRow(title: "跟进", value: needsFollowUp ? AppFormatters.relativeDueText(nextContactAt, calendar: Calendar.current) : "暂不安排")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedName: String {
        if trimmedName.isEmpty == false {
            return trimmedName
        }

        let phone = AppFormatters.sanitizedPhoneNumber(phoneNumber)
        if phone.isEmpty == false {
            return "客户 \(phone.suffix(4))"
        }

        let wechat = wechatID.trimmingCharacters(in: .whitespacesAndNewlines)
        if wechat.isEmpty == false {
            return "微信客户 \(wechat)"
        }

        return "新客户 \(AppFormatters.shortDate(.now))"
    }

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSource: String {
        sourceChannel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contactSummary: String {
        let parts = [phoneNumber, wechatID, emailAddress]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? "暂无联系方式" : parts.joined(separator: " · ")
    }

    private func save() {
        let draft = ClientRecord(
            id: UUID(),
            name: resolvedName,
            city: trimmedCity,
            phoneNumber: AppFormatters.sanitizedPhoneNumber(phoneNumber),
            wechatID: wechatID.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceChannel: trimmedSource,
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            stage: stage,
            stageMode: stageMode,
            tier: tier,
            createdAt: .now,
            lastContactAt: nil,
            nextContactAt: needsFollowUp ? nextContactAt : nil,
            isArchived: false,
            archivedAt: nil
        )

        store.upsert(client: draft)
        onSaved?(draft)
        AppHaptics.success()
        dismiss()
    }
}

private struct ClientEditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private let client: ClientRecord
    private let onSaved: ((ClientRecord) -> Void)?

    @State private var name: String
    @State private var city: String
    @State private var phoneNumber: String
    @State private var wechatID: String
    @State private var emailAddress: String
    @State private var sourceChannel: String
    @State private var notesText: String
    @State private var stage: LeadStage
    @State private var stageMode: LeadStageMode
    @State private var tier: ClientTier
    @State private var needsFollowUp: Bool
    @State private var nextContactAt: Date

    init(client: ClientRecord, onSaved: ((ClientRecord) -> Void)? = nil) {
        self.client = client
        self.onSaved = onSaved
        _name = State(initialValue: client.name)
        _city = State(initialValue: client.city)
        _phoneNumber = State(initialValue: client.phoneNumber)
        _wechatID = State(initialValue: client.wechatID)
        _emailAddress = State(initialValue: client.emailAddress)
        _sourceChannel = State(initialValue: client.sourceChannel)
        _notesText = State(initialValue: client.notesText)
        _stage = State(initialValue: client.stage)
        _stageMode = State(initialValue: client.stageMode)
        _tier = State(initialValue: client.tier)
        _needsFollowUp = State(initialValue: client.nextContactAt != nil)
        _nextContactAt = State(initialValue: client.nextContactAt ?? .now.addingTimeInterval(86_400))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(trimmedName.isEmpty ? "未命名客户" : trimmedName)
                            .font(.title3.weight(.bold))
                        HStack(spacing: 8) {
                            LeadStageBadge(stage: stage)
                            TierBadge(tier: tier)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } footer: {
                    Text("编辑客户资料时保持集中，不再把创建流程和编辑流程混在一起。")
                }

                Section("基础信息") {
                    TextField("客户名称", text: $name)
                    TextField("城市", text: $city)
                    TextField("电话", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("微信", text: $wechatID)
                        .textInputAutocapitalization(.never)
                    TextField("邮箱", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("来源渠道", text: $sourceChannel)
                }

                Section("经营设置") {
                    Picker("阶段维护方式", selection: $stageMode) {
                        ForEach(LeadStageMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if stageMode == .manual {
                        Picker("阶段", selection: $stage) {
                            ForEach(LeadStage.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("当前自动阶段")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                LeadStageBadge(stage: stage)
                            }
                            Text(stageMode.descriptionText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryInk)
                            Text("自动模式下，客户阶段会跟随已绑定订单状态更新；你仍可通过订单推进来影响结果。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.vertical, 4)
                    }

                    Picker("层级", selection: $tier) {
                        ForEach(ClientTier.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    Toggle("安排下次跟进", isOn: $needsFollowUp)

                    if needsFollowUp {
                        DatePicker("下次跟进", selection: $nextContactAt)
                    }
                }

                Section("客户备注") {
                    TextField("记录偏好、报价动态、沟通重点与风格偏好", text: $notesText, axis: .vertical)
                        .lineLimit(4...)
                }
            }
            .navigationTitle("编辑客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let draft = ClientRecord(
            id: client.id,
            name: trimmedName,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: AppFormatters.sanitizedPhoneNumber(phoneNumber),
            wechatID: wechatID.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceChannel: sourceChannel.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            stage: stage,
            stageMode: stageMode,
            tier: tier,
            createdAt: client.createdAt,
            lastContactAt: client.lastContactAt,
            nextContactAt: needsFollowUp ? nextContactAt : nil,
            isArchived: client.isArchived,
            archivedAt: client.archivedAt
        )

        store.upsert(client: draft)
        onSaved?(draft)
        AppHaptics.success()
        dismiss()
    }
}
