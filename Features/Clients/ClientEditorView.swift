import SwiftUI

struct ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private let client: ClientRecord?
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

    init(client: ClientRecord? = nil, onSaved: ((ClientRecord) -> Void)? = nil) {
        self.client = client
        self.onSaved = onSaved
        _name = State(initialValue: client?.name ?? "")
        _city = State(initialValue: client?.city ?? "")
        _phoneNumber = State(initialValue: client?.phoneNumber ?? "")
        _wechatID = State(initialValue: client?.wechatID ?? "")
        _emailAddress = State(initialValue: client?.emailAddress ?? "")
        _sourceChannel = State(initialValue: client?.sourceChannel ?? "")
        _notesText = State(initialValue: client?.notesText ?? "")
        _stage = State(initialValue: client?.stage ?? .discovery)
        _stageMode = State(initialValue: client?.stageMode ?? .manual)
        _tier = State(initialValue: client?.tier ?? .standard)
        _needsFollowUp = State(initialValue: client?.nextContactAt != nil)
        _nextContactAt = State(initialValue: client?.nextContactAt ?? .now.addingTimeInterval(86_400))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新客户" : name)
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
            .navigationTitle(client == nil ? "新增客户" : "编辑客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = ClientRecord(
            id: client?.id ?? UUID(),
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
            createdAt: client?.createdAt ?? .now,
            lastContactAt: client?.lastContactAt,
            nextContactAt: needsFollowUp ? nextContactAt : nil,
            isArchived: client?.isArchived ?? false,
            archivedAt: client?.archivedAt
        )

        store.upsert(client: draft)
        onSaved?(draft)
        AppHaptics.success()
        dismiss()
    }
}
