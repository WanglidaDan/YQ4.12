import SwiftUI

/// Booking editor is now split by intent:
/// - new bookings go through the guided `CreateBookingFlowView`
/// - existing bookings keep a focused edit form
///
/// Keeping the public initializer unchanged means every existing `BookingEditorView()`
/// entry point is automatically routed to the redesigned creation flow.
struct BookingEditorView: View {
    private let booking: BookingRecord?

    init(booking: BookingRecord? = nil) {
        self.booking = booking
    }

    var body: some View {
        if let booking {
            BookingEditFormView(booking: booking)
        } else {
            CreateBookingFlowView(context: .overview)
        }
    }
}

private struct BookingEditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private let originalBooking: BookingRecord

    @State private var title: String
    @State private var selectedClientID: UUID?
    @State private var clientName: String = ""
    @State private var clientPhoneNumber: String = ""
    @State private var clientWechatID: String = ""
    @State private var clientEmailAddress: String = ""
    @State private var clientCity: String = ""
    @State private var category: ServiceCategory
    @State private var status: BookingStatus
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var city: String
    @State private var venue: String
    @State private var addressText: String
    @State private var locationNote: String
    @State private var fee: Double
    @State private var depositPaid: Double
    @State private var deliverableText: String
    @State private var notesText: String
    @State private var shootingAttributes: [ShootingAttribute]
    @State private var crewAssignments: [BookingCrewAssignment]
    @State private var reminderOffsets: [BookingReminderOffset]
    @State private var showingConflictConfirmation = false
    @State private var crewAssignmentDraft: BookingCrewAssignmentDraft?
    @State private var didHydrateClientFields = false

    init(booking: BookingRecord) {
        self.originalBooking = booking
        _title = State(initialValue: booking.title)
        _selectedClientID = State(initialValue: booking.clientID)
        _category = State(initialValue: booking.category)
        _status = State(initialValue: booking.status)
        _startAt = State(initialValue: booking.startAt)
        _endAt = State(initialValue: booking.endAt)
        _city = State(initialValue: booking.city)
        _venue = State(initialValue: booking.venue)
        _addressText = State(initialValue: booking.addressText)
        _locationNote = State(initialValue: booking.locationNote)
        _fee = State(initialValue: booking.fee)
        _depositPaid = State(initialValue: booking.depositPaid)
        _deliverableText = State(initialValue: booking.deliverableText)
        _notesText = State(initialValue: booking.notesText)
        _shootingAttributes = State(initialValue: booking.shootingAttributes)
        _crewAssignments = State(initialValue: booking.crewAssignments)
        _reminderOffsets = State(initialValue: booking.reminderOffsets)
    }

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                essentialsSection
                crewSection
                scheduleSection
                moneySection
                detailSection
                reminderSection
                conflictSection
            }
            .navigationTitle("编辑档期")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onAppear(perform: hydrateClientFieldsIfNeeded)
            .onChange(of: selectedClientID) { _, _ in
                hydrateClientFields(force: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: saveTapped)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("当前时间可能有冲突", isPresented: $showingConflictConfirmation) {
                Button("仍然保存") {
                    saveBooking()
                }
                Button("返回调整", role: .cancel) {}
            } message: {
                Text(conflictSummaryText)
            }
            .sheet(item: $crewAssignmentDraft) { draft in
                BookingCrewAssignmentEditorView(
                    assignment: Binding(
                        get: { crewAssignmentDraft?.assignment ?? draft.assignment },
                        set: { crewAssignmentDraft?.assignment = $0 }
                    ),
                    title: draft.title
                ) { savedAssignment in
                    saveCrewAssignment(savedAssignment, replacing: draft.replacingAssignmentID)
                }
                .environment(store)
            }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(trimmedTitle.isEmpty ? "未命名档期" : trimmedTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    BookingStatusBadge(status: status)
                    ServiceCategoryBadge(category: category)
                }
                Text("\(AppFormatters.shortDate(startAt)) · \(AppFormatters.timeRange(start: startAt, end: endAt))")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("编辑页只保留关键字段；新建档期已经改为三步式快速创建流程。")
        }
    }

    private var essentialsSection: some View {
        Section("客户与拍摄内容") {
            TextField("项目标题", text: $title)

            Picker("关联客户", selection: $selectedClientID) {
                Text("暂不绑定").tag(Optional<UUID>.none)
                ForEach(store.activeClients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }

            TextField("客户姓名 / 公司", text: $clientName)
            TextField("电话", text: $clientPhoneNumber)
                .keyboardType(.phonePad)
            TextField("微信", text: $clientWechatID)
                .textInputAutocapitalization(.never)
            TextField("邮箱", text: $clientEmailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("客户城市 / 区域", text: $clientCity)

            Picker("拍摄类型", selection: $category) {
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
    }

    private var crewSection: some View {
        Section("团队分工") {
            Button {
                crewAssignmentDraft = .new()
            } label: {
                Label("添加成员分工", systemImage: "person.badge.plus")
            }

            if crewAssignments.isEmpty {
                Text("保存前后都可以补充主拍、摄像、统筹、剪辑等成员。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            } else {
                ForEach(BookingCrewAssignment.normalized(crewAssignments)) { assignment in
                    Button {
                        crewAssignmentDraft = .edit(assignment)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: assignment.role.symbolName)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.headlineText)
                                    .foregroundStyle(AppTheme.ink)
                                Text(assignment.operationalSummaryText)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteCrewAssignments)
            }
        }
    }

    private var scheduleSection: some View {
        Section("时间与地点") {
            DatePicker("开始时间", selection: $startAt)
                .onChange(of: startAt) { oldValue, newValue in
                    shiftEndDate(from: oldValue, to: newValue)
                }
            DatePicker("结束时间", selection: $endAt, in: startAt...)
            TextField("城市 / 区域", text: $city)
            TextField("场地名称", text: $venue)
            TextField("详细地址", text: $addressText, axis: .vertical)
                .lineLimit(2...4)
            TextField("到场备注", text: $locationNote, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var moneySection: some View {
        Section("报价与回款") {
            TextField("总报价", value: $fee, format: .number.precision(.fractionLength(0...0)))
                .keyboardType(.decimalPad)
            TextField("已收金额", value: $depositPaid, format: .number.precision(.fractionLength(0...0)))
                .keyboardType(.decimalPad)
            AppKeyValueRow(title: "待收", value: AppFormatters.currency(max(normalizedFee - normalizedDeposit, 0)))
        }
    }

    private var detailSection: some View {
        Section("交付与说明") {
            TextField("交付内容", text: $deliverableText, axis: .vertical)
                .lineLimit(2...5)
            TextField("项目说明", text: $notesText, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var reminderSection: some View {
        Section("提醒") {
            ForEach(BookingReminderOffset.allCases) { offset in
                Button {
                    toggleReminderOffset(offset)
                    AppHaptics.selection()
                } label: {
                    HStack {
                        Label(offset.title, systemImage: offset.symbolName)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Image(systemName: reminderOffsets.contains(offset) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(reminderOffsets.contains(offset) ? AppTheme.accent : AppTheme.secondaryInk)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var conflictSection: some View {
        if conflictBookings.isEmpty == false {
            Section("冲突提醒") {
                Label(conflictSummaryText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warning)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedFee: Double {
        max(fee, 0)
    }

    private var normalizedDeposit: Double {
        min(max(depositPaid, 0), normalizedFee)
    }

    private var trimmedClientName: String {
        clientName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasClientDraft: Bool {
        [
            clientName,
            clientPhoneNumber,
            clientWechatID,
            clientEmailAddress,
            clientCity
        ]
        .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    private var conflictBookings: [BookingRecord] {
        store.activeBookings.filter { booking in
            booking.id != originalBooking.id &&
            booking.status != .cancelled &&
            Calendar.current.isDate(booking.startAt, inSameDayAs: startAt) &&
            booking.startAt < endAt && startAt < booking.endAt
        }
    }

    private var conflictSummaryText: String {
        let heads = conflictBookings.prefix(2).map { $0.title }.joined(separator: "、")
        if conflictBookings.count > 2 {
            return "该时间段已有 \(heads) 等 \(conflictBookings.count) 个档期。"
        }
        return heads.isEmpty ? "当前时间没有发现重叠档期。" : "该时间段已有 \(heads)。"
    }

    private func saveTapped() {
        if conflictBookings.isEmpty == false {
            showingConflictConfirmation = true
        } else {
            saveBooking()
        }
    }

    private func saveBooking() {
        let resolvedClientID = saveClientDraftIfNeeded()
        let updated = BookingRecord(
            id: originalBooking.id,
            title: trimmedTitle,
            category: category,
            status: status,
            startAt: startAt,
            endAt: endAt,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressText: addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationNote: locationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: originalBooking.latitude,
            longitude: originalBooking.longitude,
            fee: normalizedFee,
            depositPaid: normalizedDeposit,
            deliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: shootingAttributes.isEmpty ? ShootingAttribute.defaultSelection(for: category) : shootingAttributes,
            crewAssignments: crewAssignments,
            reminderOffsets: reminderOffsets,
            createdAt: originalBooking.createdAt,
            clientID: resolvedClientID,
            isArchived: originalBooking.isArchived,
            archivedAt: originalBooking.archivedAt
        )

        store.upsert(booking: updated)
        if reminderOffsets.isEmpty {
            AppNotificationManager.shared.removeBookingReminders(for: updated.id)
        }
        AppHaptics.success()
        dismiss()
    }

    private func toggleReminderOffset(_ offset: BookingReminderOffset) {
        if reminderOffsets.contains(offset) {
            reminderOffsets.removeAll { $0 == offset }
        } else {
            reminderOffsets.append(offset)
            reminderOffsets.sort { $0.sortOrder < $1.sortOrder }
        }
    }

    private func shiftEndDate(from oldValue: Date, to newValue: Date) {
        let duration = endAt.timeIntervalSince(oldValue)
        endAt = max(newValue.addingTimeInterval(duration), newValue.addingTimeInterval(1_800))
    }

    private func hydrateClientFieldsIfNeeded() {
        guard didHydrateClientFields == false else { return }
        didHydrateClientFields = true
        hydrateClientFields(force: true)
    }

    private func hydrateClientFields(force: Bool) {
        guard force else { return }
        if let selectedClientID,
           let client = store.client(id: selectedClientID) {
            clientName = client.name
            clientPhoneNumber = client.phoneNumber
            clientWechatID = client.wechatID
            clientEmailAddress = client.emailAddress
            clientCity = client.city
        } else {
            clientName = ""
            clientPhoneNumber = ""
            clientWechatID = ""
            clientEmailAddress = ""
            clientCity = ""
        }
    }

    private func saveClientDraftIfNeeded() -> UUID? {
        guard hasClientDraft else { return selectedClientID }
        let clientID = selectedClientID ?? UUID()
        let existing = selectedClientID.flatMap { store.client(id: $0) }
        let normalizedName = trimmedClientName.isEmpty ? "未命名客户" : trimmedClientName
        let normalizedCity = clientCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = AppFormatters.sanitizedPhoneNumber(clientPhoneNumber)
        let normalizedWechat = clientWechatID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = clientEmailAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing,
           existing.name == normalizedName,
           existing.city == normalizedCity,
           existing.phoneNumber == normalizedPhone,
           existing.wechatID == normalizedWechat,
           existing.emailAddress == normalizedEmail {
            return selectedClientID
        }

        let client = ClientRecord(
            id: clientID,
            name: normalizedName,
            city: normalizedCity,
            phoneNumber: normalizedPhone,
            wechatID: normalizedWechat,
            emailAddress: normalizedEmail,
            sourceChannel: existing?.sourceChannel ?? "",
            notesText: existing?.notesText ?? "",
            tags: existing?.tags ?? [],
            stage: existing?.stage ?? .discovery,
            stageMode: existing?.stageMode ?? .automatic,
            tier: existing?.tier ?? .standard,
            createdAt: existing?.createdAt ?? .now,
            lastContactAt: existing?.lastContactAt,
            nextContactAt: existing?.nextContactAt,
            isArchived: existing?.isArchived ?? false,
            archivedAt: existing?.archivedAt
        )
        store.upsert(client: client)
        return clientID
    }

    private func saveCrewAssignment(_ assignment: BookingCrewAssignment, replacing assignmentID: UUID?) {
        if let assignmentID,
           let index = crewAssignments.firstIndex(where: { $0.id == assignmentID }) {
            crewAssignments[index] = assignment
        } else {
            crewAssignments.append(assignment)
        }
        crewAssignments = BookingCrewAssignment.normalized(crewAssignments)
    }

    private func deleteCrewAssignments(at offsets: IndexSet) {
        let normalizedAssignments = BookingCrewAssignment.normalized(crewAssignments)
        let idsToRemove = offsets.map { normalizedAssignments[$0].id }
        crewAssignments.removeAll { idsToRemove.contains($0.id) }
    }
}
