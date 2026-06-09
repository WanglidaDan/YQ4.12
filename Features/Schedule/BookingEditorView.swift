import SwiftUI

struct BookingEditorView: View {
    private let booking: BookingRecord?
    private let initialStartAt: Date?

    init(booking: BookingRecord? = nil, initialStartAt: Date? = nil) {
        self.booking = booking
        self.initialStartAt = initialStartAt
    }

    var body: some View {
        BookingFormPage(booking: booking, initialStartAt: initialStartAt)
    }
}

private struct BookingFormPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private let originalBooking: BookingRecord?

    @State private var title: String
    @State private var selectedClientID: UUID?
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
    @State private var showingAdvanced: Bool
    @State private var showingConflictConfirmation = false
    @State private var crewAssignmentDraft: BookingCrewAssignmentDraft?

    private let calendar = Calendar.current

    init(booking: BookingRecord?, initialStartAt: Date?) {
        self.originalBooking = booking
        let defaultStartAt = Self.defaultStartDate(from: initialStartAt)
        let defaultEndAt = Calendar.current.date(byAdding: .hour, value: 2, to: defaultStartAt) ?? defaultStartAt.addingTimeInterval(7_200)
        _title = State(initialValue: booking?.title ?? "")
        _selectedClientID = State(initialValue: booking?.clientID)
        _category = State(initialValue: booking?.category ?? .wedding)
        _status = State(initialValue: booking?.status ?? .tentative)
        _startAt = State(initialValue: booking?.startAt ?? defaultStartAt)
        _endAt = State(initialValue: booking?.endAt ?? defaultEndAt)
        _city = State(initialValue: booking?.city ?? "")
        _venue = State(initialValue: booking?.venue ?? "")
        _addressText = State(initialValue: booking?.addressText ?? "")
        _locationNote = State(initialValue: booking?.locationNote ?? "")
        _fee = State(initialValue: booking?.fee ?? 0)
        _depositPaid = State(initialValue: booking?.depositPaid ?? 0)
        _deliverableText = State(initialValue: booking?.deliverableText ?? "")
        _notesText = State(initialValue: booking?.notesText ?? "")
        _shootingAttributes = State(initialValue: booking?.shootingAttributes ?? ShootingAttribute.defaultSelection(for: .wedding))
        _crewAssignments = State(initialValue: booking?.crewAssignments ?? [])
        _reminderOffsets = State(initialValue: booking?.reminderOffsets ?? [])
        _showingAdvanced = State(initialValue: booking != nil)
    }

    private static func defaultStartDate(from seedDate: Date?) -> Date {
        guard let seedDate else { return .now }
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: seedDate) ?? seedDate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerBar
                        quickCreateHero
                        requiredHint

                        contentSection(title: "快速信息", subtitle: "只填项目标题就能保存，时间和地点可先用默认值。") {
                            labeledField("项目标题", isRequired: true) {
                                flatTextField("例如：周末婚礼跟拍", text: $title)
                            }
                            fieldDivider
                            labeledField("关联客户") {
                                clientPicker
                            }
                            fieldDivider
                            labeledField("开始时间") {
                                DatePicker("开始时间", selection: $startAt)
                                    .labelsHidden()
                                    .onChange(of: startAt) { oldValue, newValue in
                                        shiftEndDate(from: oldValue, to: newValue)
                                    }
                            }
                            fieldDivider
                            labeledField("场地") {
                                flatTextField("酒店、影棚或外景地", text: $venue)
                            }
                        }

                        advancedSection

                        if conflictBookings.isEmpty == false {
                            conflictNotice
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(.regularMaterial)
            }
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("当前时间可能有冲突", isPresented: $showingConflictConfirmation) {
                Button(originalBooking == nil ? "仍然新建" : "仍然保存") {
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

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showingAdvanced) {
            VStack(alignment: .leading, spacing: 16) {
                contentSection(title: "类型与状态") {
                    labeledField("拍摄类型") {
                        categoryPicker
                    }
                    fieldDivider
                    labeledField("当前状态") {
                        statusPicker
                    }
                }

                contentSection(title: "时间地点") {
                    labeledField("结束时间") {
                        DatePicker("结束时间", selection: $endAt, in: startAt...)
                            .labelsHidden()
                    }
                    fieldDivider
                    labeledField("城市 / 区域") {
                        flatTextField("例如：上海", text: $city)
                    }
                    fieldDivider
                    labeledField("详细地址") {
                        flatTextField("门牌、楼层、集合点", text: $addressText, axis: .vertical)
                    }
                    fieldDivider
                    labeledField("到场备注") {
                        flatTextField("停车、集合点、联系人等", text: $locationNote, axis: .vertical)
                    }
                }

                contentSection(title: "报价交付") {
                    labeledField("总报价") {
                        TextField("0", value: $fee, format: .number.precision(.fractionLength(0...0)))
                            .keyboardType(.decimalPad)
                    }
                    fieldDivider
                    labeledField("已收金额") {
                        TextField("0", value: $depositPaid, format: .number.precision(.fractionLength(0...0)))
                            .keyboardType(.decimalPad)
                    }
                    fieldDivider
                    HStack {
                        Text("待收")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(AppFormatters.currency(max(normalizedFee - normalizedDeposit, 0)))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    fieldDivider
                    labeledField("交付内容") {
                        flatTextField("精修张数、短片、相册等", text: $deliverableText, axis: .vertical)
                    }
                    fieldDivider
                    labeledField("项目说明") {
                        flatTextField("流程、偏好、注意事项", text: $notesText, axis: .vertical)
                    }
                }

                contentSection(title: "团队分工") {
                    Button {
                        crewAssignmentDraft = .new()
                        AppHaptics.tapLight()
                    } label: {
                        Label("添加成员分工", systemImage: "person.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    if crewAssignments.isEmpty == false {
                        fieldDivider
                        VStack(spacing: 0) {
                            ForEach(Array(BookingCrewAssignment.normalized(crewAssignments).enumerated()), id: \.element.id) { index, assignment in
                                crewRow(assignment)
                                if index < crewAssignments.count - 1 {
                                    fieldDivider
                                }
                            }
                        }
                    }
                }

                contentSection(title: "提醒") {
                    Text("默认不主动开启提醒，避免刚进 app 就弹权限。需要提醒时再勾选。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    fieldDivider
                    ForEach(Array(BookingReminderOffset.allCases.enumerated()), id: \.element.id) { index, offset in
                        reminderRow(offset)
                        if index < BookingReminderOffset.allCases.count - 1 {
                            fieldDivider
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: showingAdvanced ? "chevron.down.circle.fill" : "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(showingAdvanced ? "收起补充信息" : "补充报价、提醒和团队")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("这些都可以稍后在档期详情里继续补。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .tint(.primary)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(originalBooking == nil ? "新建档期" : "编辑档期")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(headerSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("取消") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .buttonStyle(.plain)
        }
    }

    private var headerSubtitle: String {
        let dateText = AppFormatters.shortDate(startAt)
        let timeText = AppFormatters.timeRange(start: startAt, end: endAt)
        return "\(dateText) · \(timeText)"
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            compactMetric("类型", value: category.title)
            Divider().frame(height: 30)
            compactMetric("状态", value: status.title)
            Divider().frame(height: 30)
            compactMetric("待收", value: AppFormatters.currency(max(normalizedFee - normalizedDeposit, 0)))
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var quickCreateHero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 42, height: 42)
                .background(Color.primary, in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text("快速建档")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("先把拍摄占住，客户、报价、分工和提醒都能之后补。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label(headerSubtitle, systemImage: "clock")
                    if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Label(venue, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var requiredHint: some View {
        if canSave == false {
            Label("填写项目标题后即可保存。", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func compactMetric(_ title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func contentSection<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var fieldDivider: some View {
        Divider()
            .overlay(Color.primary.opacity(0.06))
    }

    private func flatTextField(_ placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        TextField(placeholder, text: text, axis: axis)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .lineLimit(axis == .vertical ? 2...5 : 1...1)
    }

    private func labeledField<Content: View>(_ title: String, isRequired: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                if isRequired {
                    Text("必填")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            }

            content()
                .font(.system(size: 16, weight: .medium))
        }
    }

    private var clientPicker: some View {
        Picker("关联客户", selection: $selectedClientID) {
            Text("暂不绑定").tag(Optional<UUID>.none)
            ForEach(store.activeClients) { client in
                Text(client.name).tag(Optional(client.id))
            }
        }
    }

    private var categoryPicker: some View {
        Picker("拍摄类型", selection: $category) {
            ForEach(ServiceCategory.allCases) { item in
                Label(item.title, systemImage: item.symbolName).tag(item)
            }
        }
        .onChange(of: category) { _, newValue in
            if shootingAttributes.isEmpty {
                shootingAttributes = ShootingAttribute.defaultSelection(for: newValue)
            }
        }
    }

    private var statusPicker: some View {
        Picker("状态", selection: $status) {
            ForEach(BookingStatus.allCases) { item in
                Text(item.title).tag(item)
            }
        }
    }

    private func crewRow(_ assignment: BookingCrewAssignment) -> some View {
        Button {
            crewAssignmentDraft = .edit(assignment)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: assignment.role.symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.headlineText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(assignment.operationalSummaryText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑", systemImage: "square.and.pencil") {
                crewAssignmentDraft = .edit(assignment)
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                crewAssignments.removeAll { $0.id == assignment.id }
            }
        }
    }

    private func reminderRow(_ offset: BookingReminderOffset) -> some View {
        Button {
            toggleReminderOffset(offset)
            AppHaptics.selection()
        } label: {
            HStack(spacing: 12) {
                Label(offset.title, systemImage: offset.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: reminderOffsets.contains(offset) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reminderOffsets.contains(offset) ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var conflictNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(conflictSummaryText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var saveBar: some View {
        Button {
            saveTapped()
        } label: {
            Text(originalBooking == nil ? "保存档期" : "保存修改")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSave ? Color.primary : Color.secondary.opacity(0.35), in: Capsule())
                .shadow(color: canSave ? Color.black.opacity(0.16) : Color.clear, radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(canSave == false)
    }

    private var canSave: Bool {
        trimmedTitle.isEmpty == false
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

    private var conflictBookings: [BookingRecord] {
        store.activeBookings.filter { booking in
            booking.id != originalBooking?.id &&
            booking.status != .cancelled &&
            calendar.isDate(booking.startAt, inSameDayAs: startAt) &&
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
        let booking = BookingRecord(
            id: originalBooking?.id ?? UUID(),
            title: trimmedTitle,
            category: category,
            status: status,
            startAt: startAt,
            endAt: endAt,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressText: addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationNote: locationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: originalBooking?.latitude,
            longitude: originalBooking?.longitude,
            fee: normalizedFee,
            depositPaid: normalizedDeposit,
            deliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: shootingAttributes.isEmpty ? ShootingAttribute.defaultSelection(for: category) : shootingAttributes,
            crewAssignments: crewAssignments,
            reminderOffsets: reminderOffsets,
            createdAt: originalBooking?.createdAt ?? .now,
            clientID: selectedClientID,
            isArchived: originalBooking?.isArchived ?? false,
            archivedAt: originalBooking?.archivedAt
        )

        store.upsert(booking: booking)
        if reminderOffsets.isEmpty {
            AppNotificationManager.shared.removeBookingReminders(for: booking.id)
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

    private func saveCrewAssignment(_ assignment: BookingCrewAssignment, replacing assignmentID: UUID?) {
        if let assignmentID,
           let index = crewAssignments.firstIndex(where: { $0.id == assignmentID }) {
            crewAssignments[index] = assignment
        } else {
            crewAssignments.append(assignment)
        }
        crewAssignments = BookingCrewAssignment.normalized(crewAssignments)
    }
}
