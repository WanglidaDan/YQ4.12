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

    private enum Step: Int, CaseIterable {
        case essentials
        case business
        case confirm

        var title: String {
            switch self {
            case .essentials: "快速建档"
            case .business: "经营信息"
            case .confirm: "确认客户"
            }
        }
    }

    let onSaved: ((ClientRecord) -> Void)?

    @State private var step: Step = .essentials
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
    @State private var needsFollowUp = true
    @State private var nextContactAt = Date().addingTimeInterval(86_400)

    var body: some View {
        NavigationStack {
            Form {
                progressSection

                switch step {
                case .essentials:
                    essentialsSection
                case .business:
                    businessSection
                case .confirm:
                    confirmSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if step == .confirm {
                        Button("创建", action: save)
                            .disabled(trimmedName.isEmpty)
                    } else {
                        Button("下一步", action: goForward)
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
        }
    }

    private var progressSection: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.self) { item in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(item.rawValue <= step.rawValue ? AppTheme.accent : AppTheme.panelStrong)
                            .frame(width: 10, height: 10)
                        Text(item.title)
                            .font(AppTypography.meta)
                            .foregroundStyle(item == step ? AppTheme.ink : AppTheme.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("先把客户关系保存下来，来源、层级和跟进时间可以后补。")
        }
    }

    private var essentialsSection: some View {
        Group {
            Section("客户是谁") {
                TextField("客户名称 / 昵称 / 公司名", text: $name)
                TextField("城市 / 区域", text: $city)
            }

            Section("怎么联系") {
                TextField("电话", text: $phoneNumber)
                    .keyboardType(.phonePad)
                TextField("微信", text: $wechatID)
                    .textInputAutocapitalization(.never)
                TextField("邮箱", text: $emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var businessSection: some View {
        Group {
            Section("来源与价值") {
                TextField("来源渠道，例如：小红书 / 转介绍 / 老客户复购", text: $sourceChannel)

                Picker("客户层级", selection: $tier) {
                    ForEach(ClientTier.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Picker("客户阶段", selection: $stage) {
                    ForEach(LeadStage.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }

            Section("跟进计划") {
                Toggle("安排下次跟进", isOn: $needsFollowUp)
                if needsFollowUp {
                    DatePicker("下次跟进", selection: $nextContactAt)
                }
            }

            Section("备注") {
                TextField("偏好、预算、沟通重点、拍摄风格等", text: $notesText, axis: .vertical)
                    .lineLimit(3...7)
            }
        }
    }

    private var confirmSection: some View {
        Group {
            Section("客户摘要") {
                AppKeyValueRow(title: "客户", value: trimmedName)
                AppKeyValueRow(title: "城市", value: trimmedCity.isEmpty ? "未填写" : trimmedCity)
                AppKeyValueRow(title: "联系方式", value: contactSummary)
                AppKeyValueRow(title: "来源", value: trimmedSource.isEmpty ? "未填写" : trimmedSource)
                AppKeyValueRow(title: "阶段", value: stage.title)
                AppKeyValueRow(title: "层级", value: tier.title)
                AppKeyValueRow(title: "下次跟进", value: needsFollowUp ? AppFormatters.relativeDueText(nextContactAt, calendar: Calendar.current) : "暂不安排")
            }

            Section("创建后可以继续") {
                Label("从客户详情新建档期", systemImage: "calendar.badge.plus")
                Label("在经营中心补合同、收据、发票", systemImage: "doc.text")
                Label("按跟进时间自动进入优先关注", systemImage: "bell.badge")
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func goForward() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        AppHaptics.selection()
    }

    private func save() {
        let draft = ClientRecord(
            id: UUID(),
            name: trimmedName,
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
