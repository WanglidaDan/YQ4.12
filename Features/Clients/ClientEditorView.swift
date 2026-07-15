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
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("客户") {
                    TextField("客户名称", text: $name)
                    TextField("电话", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("微信", text: $wechatID)
                        .textInputAutocapitalization(.never)
                }

                if showingBusinessFields {
                    Section("更多信息") {
                        TextField("城市 / 区域", text: $city)
                        TextField("邮箱", text: $emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("来源渠道", text: $sourceChannel)

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

                        Toggle("安排下次跟进", isOn: $needsFollowUp)
                        if needsFollowUp {
                            DatePicker("下次跟进", selection: $nextContactAt)
                        }

                        TextField("备注", text: $notesText, axis: .vertical)
                            .lineLimit(3...6)
                    }
                } else {
                    Section {
                        Button("更多信息", systemImage: "ellipsis.circle") {
                            withAnimation(.snappy) {
                                showingBusinessFields = true
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("新建客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark", action: save)
                        .fontWeight(.semibold)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if $0 == false { saveErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "客户没有保存成功。")
            }
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

        return "未命名客户"
    }

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSource: String {
        sourceChannel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard store.canCurrentUserPerform(.manageClients) else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "当前账号没有管理客户权限。"
            AppHaptics.error()
            return
        }

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

        guard store.client(id: draft.id) != nil else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "客户没有写入成功。"
            AppHaptics.error()
            return
        }

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
