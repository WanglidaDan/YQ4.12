import SwiftUI
import UIKit
import CoreLocation
import Contacts
import UserNotifications

struct BookingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(StudioStore.self) private var store

    private let booking: BookingRecord?

    @State private var title: String
    @State private var category: ServiceCategory
    @State private var status: BookingStatus
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var venue: String
    @State private var city: String
    @State private var addressText: String
    @State private var locationNote: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var fee: Double
    @State private var depositPaid: Double
    @State private var deliverableText: String
    @State private var notesText: String
    @State private var shootingAttributes: [ShootingAttribute]
    @State private var crewAssignments: [BookingCrewAssignment]
    @State private var selectedClientID: UUID?
    @State private var reminderOffsets: [BookingReminderOffset]
    @State private var shouldCreateFollowUp = false
    @State private var isResolvingAddress = false
    @State private var addressStatusMessage: String?
    @State private var addressErrorMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var hasAppliedInitialDefaults = false
    @State private var keepsDepositSyncedWithDefaultRatio: Bool
    @State private var crewAssignmentEditorDraft = BookingCrewAssignment(memberName: "", role: .leadPhoto)
    @State private var showingCrewAssignmentEditor = false
    @State private var editingCrewAssignmentID: UUID?
    @State private var showingInlineClientEditor = false

    init(booking: BookingRecord? = nil) {
        self.booking = booking
        _title = State(initialValue: booking?.title ?? "")
        _category = State(initialValue: booking?.category ?? .wedding)
        _status = State(initialValue: booking?.status ?? .inquiry)
        _startAt = State(initialValue: booking?.startAt ?? .now.addingTimeInterval(86_400))
        _endAt = State(initialValue: booking?.endAt ?? .now.addingTimeInterval(86_400 + 3600 * 4))
        _venue = State(initialValue: booking?.venue ?? "")
        _city = State(initialValue: booking?.city ?? "")
        _addressText = State(initialValue: booking?.addressText ?? "")
        _locationNote = State(initialValue: booking?.locationNote ?? "")
        _latitude = State(initialValue: booking?.latitude)
        _longitude = State(initialValue: booking?.longitude)
        _fee = State(initialValue: booking?.fee ?? 0)
        _depositPaid = State(initialValue: booking?.depositPaid ?? 0)
        _deliverableText = State(initialValue: booking?.deliverableText ?? "")
        _notesText = State(initialValue: booking?.notesText ?? "")
        _shootingAttributes = State(initialValue: booking?.shootingAttributes ?? ShootingAttribute.defaultSelection(for: booking?.category ?? .wedding))
        _crewAssignments = State(initialValue: booking?.crewAssignments ?? [])
        _selectedClientID = State(initialValue: booking?.clientID)
        _reminderOffsets = State(initialValue: booking?.reminderOffsets ?? BookingReminderOffset.defaultSelection)
        _keepsDepositSyncedWithDefaultRatio = State(initialValue: booking == nil)
    }

    private var paymentRatio: Double {
        guard fee > 0 else { return 0 }
        return min(max(depositPaid / fee, 0), 1)
    }

    private var rawAddressInput: String {
        [city, venue, addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private var hasResolvedCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    private var templateCandidates: [BookingTemplate] {
        store.templates.sorted { lhs, rhs in
            let lhsMatches = lhs.category == category
            let rhsMatches = rhs.category == category
            if lhsMatches != rhsMatches {
                return lhsMatches && rhsMatches == false
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var selectedClient: ClientRecord? {
        guard let selectedClientID else { return nil }
        return store.client(id: selectedClientID)
    }

    private var selectedClientContactText: String {
        selectedClient?.preferredContactText ?? "暂无联系方式"
    }

    private var isEditingLockedByPayments: Bool {
        guard let booking else { return false }
        return store.hasManualPayments(for: booking.id)
    }

    private var feeBinding: Binding<Double> {
        Binding(
            get: { fee },
            set: { newValue in
                fee = max(newValue, 0)
                guard booking == nil, keepsDepositSyncedWithDefaultRatio else { return }
                depositPaid = (fee * store.settings.defaultDepositRatio).rounded()
            }
        )
    }

    private var depositBinding: Binding<Double> {
        Binding(
            get: { depositPaid },
            set: { newValue in
                keepsDepositSyncedWithDefaultRatio = false
                depositPaid = max(newValue, 0)
            }
        )
    }

    private var shootingAttributesSummary: String {
        if shootingAttributes.isEmpty {
            return "未设置"
        }
        return shootingAttributes.map(\.title).joined(separator: "、")
    }

    private var crewAssignmentsSummary: String {
        crewAssignments.isEmpty ? "未添加" : "已添加 \(crewAssignments.count) 人"
    }

    private var pricingSummary: String {
        let feeText = fee > 0 ? AppFormatters.currency(fee) : "未报价"
        let depositText = depositPaid > 0 ? AppFormatters.currency(depositPaid) : "未收款"
        return "\(feeText) · \(depositText)"
    }

    private var reminderSummary: String {
        if reminderOffsets.isEmpty {
            return shouldCreateFollowUp ? "仅跟进" : "未设置"
        }
        return "\(reminderOffsets.count) 个提醒"
    }

    private var notesSummary: String {
        notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写" : "已填写"
    }

    private var addressSummary: String {
        let parts = [city, venue]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? "未填写地点" : parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新档期" : title)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            BookingStatusBadge(status: status)
                            ServiceCategoryBadge(category: category)
                        }
                        Text("\(AppFormatters.shortDate(startAt)) · \(AppFormatters.timeRange(start: startAt, end: endAt))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                Section("主要信息") {
                    TextField("项目标题（例如 婚礼跟拍 / 企业形象照 / 宣传片拍摄）", text: $title)

                    Picker("关联客户", selection: $selectedClientID) {
                        Text("暂不绑定").tag(Optional<UUID>.none)
                        ForEach(store.clients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }

                    if let selectedClient {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedClient.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(selectedClientContactText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }

                    Button("先新建客户") {
                        showingInlineClientEditor = true
                    }
                    .font(.subheadline.weight(.semibold))

                    Picker("服务类别", selection: $category) {
                        ForEach(ServiceCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    Picker("状态", selection: $status) {
                        ForEach(BookingStatus.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        scheduleAndLocationEditorView
                    } label: {
                        settingsRow(
                            title: "时间与地点",
                            value: addressSummary,
                            systemImage: "calendar.badge.clock"
                        )
                    }
                }

                Section("更多设置") {
                    NavigationLink {
                        pricingAndDeliverablesEditorView
                    } label: {
                        settingsRow(
                            title: "报价与交付",
                            value: pricingSummary,
                            systemImage: "yensign.square"
                        )
                    }

                    NavigationLink {
                        reminderEditorView
                    } label: {
                        settingsRow(
                            title: "提醒与跟进",
                            value: reminderSummary,
                            systemImage: "bell.badge"
                        )
                    }

                    NavigationLink {
                        notesEditorView
                    } label: {
                        settingsRow(
                            title: "项目说明",
                            value: notesSummary,
                            systemImage: "note.text"
                        )
                    }

                    NavigationLink {
                        shootingAttributesEditorView
                    } label: {
                        settingsRow(
                            title: "拍摄属性",
                            value: shootingAttributesSummary,
                            systemImage: "slider.horizontal.3"
                        )
                    }

                    NavigationLink {
                        crewAssignmentsEditorView
                    } label: {
                        settingsRow(
                            title: "团队分工",
                            value: crewAssignmentsSummary,
                            systemImage: "person.3"
                        )
                    }

                    if templateCandidates.isEmpty == false {
                        NavigationLink {
                            templatePickerView
                        } label: {
                            settingsRow(
                                title: "套用模板",
                                value: "预填常用内容",
                                systemImage: "square.grid.2x2"
                            )
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(booking == nil ? "新增档期" : "编辑档期")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                applyInitialDefaultsIfNeeded()
                syncFollowUpToggleIfNeeded()
                await refreshNotificationStatus()
            }
            .onChange(of: reminderOffsets) { _, offsets in
                guard offsets.isEmpty == false else { return }
                Task { await refreshNotificationStatus() }
            }
            .sheet(isPresented: $showingInlineClientEditor) {
                ClientEditorView { client in
                    selectedClientID = client.id
                }
                .environment(store)
            }
            .sheet(isPresented: $showingCrewAssignmentEditor) {
                BookingCrewAssignmentEditorView(
                    assignment: $crewAssignmentEditorDraft,
                    title: editingCrewAssignmentID == nil ? "新增分工" : "编辑分工"
                ) { updated in
                    upsertCrewAssignment(updated)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("地址解析失败", isPresented: Binding(
                get: { addressErrorMessage != nil },
                set: { if $0 == false { addressErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(addressErrorMessage ?? "")
            }
        }
    }

    private var scheduleAndLocationEditorView: some View {
        Form {
            Section("时间") {
                DatePicker("开始时间", selection: $startAt)
                DatePicker("结束时间", selection: $endAt, in: startAt...)
            }

            Section("地点") {
                TextField("城市 / 区域", text: $city)
                TextField("场地名称（酒店 / 摄影棚 / 公司名）", text: $venue)
                BookingMultilineField(
                    title: "详细地址",
                    prompt: "例如：XX 路 88 号 3 楼 301",
                        text: $addressText,
                        minHeight: 76
                    )
                    BookingMultilineField(
                        title: "到场备注",
                        prompt: "例如：楼层 / 停车 / 联系提示",
                        text: $locationNote,
                        minHeight: 68
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Button {
                                pasteAddressFromClipboard()
                            } label: {
                                Label("粘贴地址", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                Task { await resolveAddress() }
                            } label: {
                                Label(isResolvingAddress ? "解析中" : "生成真实地址", systemImage: "location.magnifyingglass")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                            .disabled(rawAddressInput.isEmpty || isResolvingAddress)
                        }

                        if let addressStatusMessage, addressStatusMessage.isEmpty == false {
                            Label(addressStatusMessage, systemImage: hasResolvedCoordinate ? "checkmark.seal.fill" : "mappin.circle")
                                .font(.caption)
                                .foregroundStyle(hasResolvedCoordinate ? AppTheme.success : AppTheme.secondaryInk)
                        }
                    }
                    .padding(.top, 4)
            }
        }
        .navigationTitle("时间与地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var templatePickerView: some View {
        List {
            Section {
                ForEach(templateCandidates) { template in
                    Button {
                        applyTemplate(template)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(template.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    if template.category == category {
                                        Text("推荐")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(AppTheme.accentDeep)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.accentSoft.opacity(0.4), in: Capsule())
                                    }
                                }
                                Text(template.category.title)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                Text("\(AppFormatters.currency(template.defaultPrice)) · \(template.defaultDurationHours) 小时")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                            Spacer(minLength: 12)
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("模板会预填报价、时长、交付内容和提醒时间，保存前都还能改。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("套用模板")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shootingAttributesEditorView: some View {
        List {
            Section {
                ForEach(ShootingAttribute.allCases) { attribute in
                    Button {
                        toggleShootingAttribute(attribute)
                        AppHaptics.tapLight()
                    } label: {
                        HStack(spacing: 12) {
                            Label(attribute.title, systemImage: attribute.symbolName)
                                .foregroundStyle(AppTheme.ink)
                            Spacer(minLength: 0)
                            if shootingAttributes.contains(attribute) {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("拍摄属性会影响档期标签、团队分工理解和后续提醒。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("拍摄属性")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var crewAssignmentsEditorView: some View {
        List {
            Section {
                if crewAssignments.isEmpty {
                    ContentUnavailableView(
                        "还没有添加分工",
                        systemImage: "person.3.sequence",
                        description: Text("适合婚礼、活动、直播或多人跟拍项目。")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(crewAssignments) { assignment in
                        Button {
                            crewAssignmentEditorDraft = assignment
                            editingCrewAssignmentID = assignment.id
                            showingCrewAssignmentEditor = true
                            AppHaptics.selection()
                        } label: {
                            assignmentListRow(assignment)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除", role: .destructive) {
                                crewAssignments.removeAll { $0.id == assignment.id }
                                AppHaptics.tapLight()
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    crewAssignmentEditorDraft = BookingCrewAssignment(memberName: "", role: .leadPhoto)
                    editingCrewAssignmentID = nil
                    showingCrewAssignmentEditor = true
                    AppHaptics.tapLight()
                } label: {
                    Label("添加分工", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("把成员角色、负责内容和到场位置拆开写清，现场协作会顺很多。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("团队分工")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pricingAndDeliverablesEditorView: some View {
        Form {
            Section("报价") {
                TextField("总报价（元，例如 6800）", value: feeBinding, format: .number.precision(.fractionLength(0...0)))
                    .keyboardType(.decimalPad)
                TextField("已收金额（没有回款流水时）", value: depositBinding, format: .number.precision(.fractionLength(0...0)))
                    .keyboardType(.decimalPad)
                    .disabled(isEditingLockedByPayments)
                ProgressView(value: paymentRatio)
                    .tint(AppTheme.accentWarm)
                Text("已收进度：\(AppFormatters.percent(paymentRatio))，待收 \(AppFormatters.currency(max(fee - depositPaid, 0)))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                if isEditingLockedByPayments {
                    Text("当前订单已有付款流水，请到订单详情里的“更新回款”维护具体记录。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                }
            }

            Section {
                BookingMultilineField(
                    title: "交付内容",
                    prompt: "例如：精修 60 张 + 花絮 1 条",
                    text: $deliverableText,
                    minHeight: 84
                )
            } header: {
                Text("交付")
            } footer: {
                Text("建议写清精修张数、底片是否全送、短视频条数和交付周期。")
            }
        }
        .navigationTitle("报价与交付")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reminderEditorView: some View {
        Form {
            Section {
                Toggle("自动创建拍前确认跟进", isOn: $shouldCreateFollowUp)
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(BookingReminderOffset.allCases) { offset in
                        Button {
                            toggleReminderOffset(offset)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: offset.symbolName)
                                Text(offset.title)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: reminderOffsets.contains(offset) ? "checkmark.circle.fill" : "circle")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(reminderOffsets.contains(offset) ? AppTheme.accentWarmDeep : AppTheme.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(reminderOffsets.contains(offset) ? AppTheme.accentSurface : AppTheme.panelStrong)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if reminderOffsets.isEmpty {
                    Text("未选择系统提醒时间，保存后不会发送拍摄通知。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                } else {
                    notificationPermissionHint
                }

                if shouldCreateFollowUp {
                    Text("保存后会自动创建一条拍前 2 天的确认跟进，方便核对流程、地点和联系人。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            } header: {
                Text("系统提醒时间")
            } footer: {
                Text("支持机型可通过锁屏与灵动岛展示即将开始的拍摄提醒卡片。")
            }
        }
        .navigationTitle("提醒与跟进")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notesEditorView: some View {
        Form {
            Section {
                BookingMultilineField(
                    title: "项目说明",
                    prompt: "服装、流程、联系人、机位需求等",
                    text: $notesText,
                    minHeight: 180
                )
            }
        }
        .navigationTitle("项目说明")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
        }
    }

    private func assignmentListRow(_ assignment: BookingCrewAssignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Label(assignment.headlineText, systemImage: assignment.role.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            if assignment.summaryText.isEmpty == false {
                Text(assignment.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
            }

            Text(assignment.locationSummaryText)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var notificationPermissionHint: some View {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            Text("已开启系统通知，保存后会按所选时间点提醒。")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("系统通知未开启，保存后不会收到提醒。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
                Button("打开系统设置") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
                .buttonStyle(.bordered)
            }
        case .notDetermined:
            Text("保存时会请求系统通知权限，用于在拍摄前 3 天、1 天、当天和开拍前 2 小时提醒你。")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
        @unknown default:
            Text("系统通知状态暂不可用，保存后会尝试请求提醒权限。")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
        }
    }

    private func applyInitialDefaultsIfNeeded() {
        guard booking == nil, hasAppliedInitialDefaults == false else { return }
        hasAppliedInitialDefaults = true

        let defaults = store.settings

        if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            venue = defaults.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesText = defaults.defaultNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if fee > 0, depositPaid <= 0 {
            depositPaid = (fee * defaults.defaultDepositRatio).rounded()
        }
    }

    private func syncFollowUpToggleIfNeeded() {
        guard let booking else { return }
        shouldCreateFollowUp = store.touchpoints.contains {
            $0.bookingID == booking.id && $0.source == .systemPreShootConfirmation && $0.isArchived == false
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFee = max(fee, 0)
        let normalizedDeposit = min(max(depositPaid, 0), normalizedFee)

        let draft = BookingRecord(
            id: booking?.id ?? UUID(),
            title: trimmedTitle,
            category: category,
            status: status,
            startAt: startAt,
            endAt: endAt,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressText: addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationNote: locationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            fee: normalizedFee,
            depositPaid: normalizedDeposit,
            deliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: shootingAttributes,
            crewAssignments: crewAssignments,
            reminderOffsets: reminderOffsets,
            createdAt: booking?.createdAt ?? .now,
            clientID: selectedClientID
        )

        store.upsert(booking: draft)

        if reminderOffsets.isEmpty {
            AppNotificationManager.shared.removeBookingReminders(for: draft.id)
        }

        let existingSystemReminder = store.touchpoints.first {
            $0.bookingID == draft.id && $0.source == .systemPreShootConfirmation
        }

        if shouldCreateFollowUp {
            let dueAt = Calendar.current.date(byAdding: .day, value: -2, to: startAt) ?? startAt
            let preservedDetails = existingSystemReminder?.detailsText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reminder = TouchpointRecord(
                id: existingSystemReminder?.id ?? UUID(),
                title: "\(trimmedTitle) 拍前确认",
                detailsText: preservedDetails.isEmpty ? "确认时间线、地点、联系人与交付要求。" : preservedDetails,
                dueAt: dueAt,
                channel: existingSystemReminder?.channel ?? .wechat,
                priority: status == .tentative ? .high : .medium,
                isComplete: existingSystemReminder?.isComplete ?? false,
                completedAt: existingSystemReminder?.completedAt,
                createdAt: existingSystemReminder?.createdAt ?? .now,
                clientID: selectedClientID,
                bookingID: draft.id,
                isArchived: false,
                archivedAt: nil,
                isSystemReminderEnabled: true,
                source: .systemPreShootConfirmation
            )
            store.upsert(touchpoint: reminder)
        } else if let existingSystemReminder, existingSystemReminder.isArchived == false {
            store.archiveTouchpoint(existingSystemReminder.id)
        }

        AppHaptics.success()
        dismiss()
    }

    private func upsertCrewAssignment(_ assignment: BookingCrewAssignment) {
        let normalized = BookingCrewAssignment.normalized([assignment]).first
        guard let normalized else { return }

        if let index = crewAssignments.firstIndex(where: { $0.id == normalized.id }) {
            crewAssignments[index] = normalized
        } else {
            crewAssignments.append(normalized)
        }
        crewAssignments = BookingCrewAssignment.normalized(crewAssignments)
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await AppNotificationManager.shared.authorizationStatus()
    }

    private func toggleReminderOffset(_ offset: BookingReminderOffset) {
        if reminderOffsets.contains(offset) {
            reminderOffsets.removeAll { $0 == offset }
        } else {
            reminderOffsets.append(offset)
        }
        reminderOffsets = BookingReminderOffset.normalized(reminderOffsets)
        AppHaptics.tapLight()
    }

    private func applyTemplate(_ template: BookingTemplate) {
        title = template.name
        category = template.category
        endAt = Calendar.current.date(byAdding: .hour, value: max(template.defaultDurationHours, 1), to: startAt) ?? endAt
        fee = template.defaultPrice
        depositPaid = (template.defaultPrice * template.defaultDepositRatio).rounded()
        deliverableText = template.defaultDeliverableText
        notesText = template.defaultNotesText
        shootingAttributes = template.defaultShootingAttributes
        reminderOffsets = BookingReminderOffset.suggestedSelection(defaultReminderDays: template.defaultReminderDays)
        keepsDepositSyncedWithDefaultRatio = false
        AppHaptics.selection()
    }

    private func toggleShootingAttribute(_ attribute: ShootingAttribute) {
        if shootingAttributes.contains(attribute) {
            shootingAttributes.removeAll { $0 == attribute }
        } else {
            shootingAttributes.append(attribute)
        }
        shootingAttributes = ShootingAttribute.normalized(shootingAttributes)
    }

    private func pasteAddressFromClipboard() {
        guard let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), pasted.isEmpty == false else {
            addressErrorMessage = "剪贴板里没有可用的地址文本。"
            AppHaptics.error()
            return
        }

        if addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addressText = pasted
        } else {
            addressText = pasted
        }

        if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            venue = firstMeaningfulLine(in: pasted)
        }
        addressStatusMessage = "已粘贴地址，点击“生成真实地址”可自动校验并补齐坐标。"
        latitude = nil
        longitude = nil
    }

    private func firstMeaningfulLine(in text: String) -> String {
        text
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false }) ?? ""
    }

    private func resolveAddress() async {
        let query = rawAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            addressErrorMessage = "请先输入或粘贴地点信息。"
            AppHaptics.error()
            return
        }

        isResolvingAddress = true
        defer { isResolvingAddress = false }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard let placemark = placemarks.first, let location = placemark.location else {
                addressErrorMessage = "没有找到足够准确的地址结果，请补充门牌、园区或酒店信息后再试。"
                AppHaptics.error()
                return
            }

            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            if let locality = placemark.locality ?? placemark.administrativeArea, locality.isEmpty == false {
                city = locality
            }
            if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let name = placemark.name, name.isEmpty == false {
                venue = name
            }
            addressText = formattedAddress(from: placemark, fallback: query)
            addressStatusMessage = "已生成真实地址，可直接一键导航。"
            AppHaptics.success()
        } catch {
            addressErrorMessage = "地址解析失败，请检查文本是否包含城市、场地名或详细门牌。"
            AppHaptics.error()
        }
    }

    private func formattedAddress(from placemark: CLPlacemark, fallback: String) -> String {
        if let postalAddress = placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            let formatted = formatter.string(from: postalAddress)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if formatted.isEmpty == false {
                return formatted
            }
        }

        let parts = [placemark.administrativeArea, placemark.locality, placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }
        let merged = parts.joined(separator: " ")
        return merged.isEmpty ? fallback : merged
    }
}
