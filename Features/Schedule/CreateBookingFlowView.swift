import SwiftUI

/// Carries the entry-point intent into the booking creation flow so a new schedule
/// can be prefilled from the current screen instead of opening a blank database-style form.
struct CreateBookingContext: Hashable {
    enum Source: Hashable {
        case overview
        case schedule
        case clientDetail
        case team
        case quickAction
    }

    var source: Source
    var defaultDate: Date?
    var defaultClientID: UUID?
    var defaultCrewMemberName: String?
    var defaultCategory: ServiceCategory?
    var defaultTitle: String?

    static let overview = CreateBookingContext(source: .overview)

    static func schedule(focusDate: Date, crewMemberName: String? = nil) -> CreateBookingContext {
        CreateBookingContext(
            source: .schedule,
            defaultDate: focusDate,
            defaultCrewMemberName: crewMemberName
        )
    }

    static func clientDetail(clientID: UUID) -> CreateBookingContext {
        CreateBookingContext(source: .clientDetail, defaultClientID: clientID)
    }
}

/// A focused, context-aware flow for creating a new shooting schedule.
///
/// This intentionally separates creation from `BookingEditorView`'s full edit form:
/// quick-create captures the minimum viable schedule first, then lets the user add
/// price, delivery, reminders, and team assignment without making the first screen noisy.
struct CreateBookingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private enum Step: Int, CaseIterable {
        case essentials
        case details
        case confirm

        var title: String {
            switch self {
            case .essentials: "快速创建"
            case .details: "补充信息"
            case .confirm: "确认档期"
            }
        }
    }

    let context: CreateBookingContext

    @State private var step: Step = .essentials
    @State private var title: String
    @State private var selectedClientID: UUID?
    @State private var category: ServiceCategory
    @State private var status: BookingStatus = .inquiry
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var city = ""
    @State private var venue: String
    @State private var addressText = ""
    @State private var fee: Double = 0
    @State private var depositPaid: Double = 0
    @State private var deliverableText = ""
    @State private var notesText: String
    @State private var shouldCreateFollowUp = true
    @State private var selectedCrewMemberName: String
    @State private var showingConflictConfirmation = false

    init(context: CreateBookingContext = .overview) {
        self.context = context
        let category = context.defaultCategory ?? .wedding
        let start = Self.normalizedStartDate(from: context.defaultDate ?? .now.addingTimeInterval(86_400))
        let end = Calendar.current.date(byAdding: .hour, value: 4, to: start) ?? start.addingTimeInterval(14_400)
        let contextTitle = context.defaultTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        _title = State(initialValue: contextTitle.isEmpty ? Self.defaultTitle(for: context.source) : contextTitle)
        _selectedClientID = State(initialValue: context.defaultClientID)
        _category = State(initialValue: category)
        _startAt = State(initialValue: start)
        _endAt = State(initialValue: end)
        _venue = State(initialValue: "")
        _notesText = State(initialValue: "")
        _selectedCrewMemberName = State(initialValue: context.defaultCrewMemberName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                progressSection

                switch step {
                case .essentials:
                    essentialsSection
                case .details:
                    detailsSection
                case .confirm:
                    confirmSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                applyStoreDefaultsIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if step == .confirm {
                        Button("创建", action: saveTapped)
                            .disabled(isEssentialsIncomplete)
                    } else {
                        Button("下一步", action: goForward)
                            .disabled(isEssentialsIncomplete)
                    }
                }
            }
            .confirmationDialog("当前时间可能有冲突", isPresented: $showingConflictConfirmation) {
                Button("仍然创建") {
                    saveBooking()
                }
                Button("返回调整", role: .cancel) {}
            } message: {
                Text(conflictSummaryText)
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
            Text("先把客户、内容、时间、地点、负责人定下来，其他信息可以后补。")
        }
    }

    private var essentialsSection: some View {
        Group {
            Section("客户与拍摄内容") {
                Picker("关联客户", selection: $selectedClientID) {
                    Text("暂不绑定").tag(Optional<UUID>.none)
                    ForEach(store.activeClients) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }

                TextField("项目标题", text: $title)

                Picker("拍摄类型", selection: $category) {
                    ForEach(ServiceCategory.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Picker("当前状态", selection: $status) {
                    ForEach(BookingStatus.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }

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
            }

            Section("负责人") {
                Picker("默认负责人", selection: $selectedCrewMemberName) {
                    Text("暂不分配").tag("")
                    ForEach(store.activeCrewMemberNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    if selectedCrewMemberName.isEmpty == false,
                       store.activeCrewMemberNames.contains(selectedCrewMemberName) == false {
                        Text(selectedCrewMemberName).tag(selectedCrewMemberName)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section("报价与回款") {
                TextField("总报价", value: $fee, format: .number.precision(.fractionLength(0...0)))
                    .keyboardType(.decimalPad)
                TextField("已收金额", value: $depositPaid, format: .number.precision(.fractionLength(0...0)))
                    .keyboardType(.decimalPad)
                Text("待收：\(AppFormatters.currency(max(fee - depositPaid, 0)))")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Section("交付与备注") {
                TextField("交付内容，例如：精修 60 张 + 花絮 1 条", text: $deliverableText, axis: .vertical)
                    .lineLimit(2...5)
                TextField("项目说明、客户偏好、流程注意事项", text: $notesText, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("自动动作") {
                Toggle("创建拍前确认跟进", isOn: $shouldCreateFollowUp)
                Text("创建后会保留系统提醒，并可在详情里继续补充分工、回款和合同资料。")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private var confirmSection: some View {
        Group {
            Section("档期摘要") {
                AppKeyValueRow(title: "项目", value: trimmedTitle)
                AppKeyValueRow(title: "客户", value: selectedClientName)
                AppKeyValueRow(title: "类型", value: category.title)
                AppKeyValueRow(title: "时间", value: "\(AppFormatters.shortDate(startAt)) · \(AppFormatters.timeRange(start: startAt, end: endAt))")
                AppKeyValueRow(title: "地点", value: locationSummary)
                AppKeyValueRow(title: "负责人", value: selectedCrewMemberName.isEmpty ? "暂不分配" : selectedCrewMemberName)
                AppKeyValueRow(title: "报价", value: fee > 0 ? AppFormatters.currency(fee) : "未报价")
            }

            if conflictBookings.isEmpty == false {
                Section("冲突提醒") {
                    Label(conflictSummaryText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warning)
                }
            }

            Section("创建后自动生成") {
                Label("系统拍摄提醒", systemImage: "bell.badge")
                if shouldCreateFollowUp {
                    Label("拍前确认跟进", systemImage: "checklist")
                }
                Label("可继续补充合同、回款、收据和发票", systemImage: "doc.text")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEssentialsIncomplete: Bool {
        trimmedTitle.isEmpty
    }

    private var selectedClientName: String {
        guard let selectedClientID,
              let client = store.client(id: selectedClientID) else {
            return "暂不绑定"
        }
        return client.name
    }

    private var locationSummary: String {
        let parts = [city, venue, addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? "未填写地点" : parts.joined(separator: " · ")
    }

    private var normalizedFee: Double {
        max(fee, 0)
    }

    private var normalizedDeposit: Double {
        min(max(depositPaid, 0), normalizedFee)
    }

    private var crewAssignments: [BookingCrewAssignment] {
        let name = selectedCrewMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return [] }
        return [BookingCrewAssignment(memberName: name, role: .leadPhoto)]
    }

    private var conflictBookings: [BookingRecord] {
        store.activeBookings.filter { booking in
            booking.status != .cancelled &&
            Calendar.current.isDate(booking.startAt, inSameDayAs: startAt) &&
            booking.startAt < endAt && startAt < booking.endAt
        }
    }

    private var conflictSummaryText: String {
        if conflictBookings.isEmpty {
            return "当前时间没有发现重叠档期。"
        }
        let heads = conflictBookings.prefix(2).map { $0.title }.joined(separator: "、")
        if conflictBookings.count > 2 {
            return "该时间段已有 \(heads) 等 \(conflictBookings.count) 个档期。"
        }
        return "该时间段已有 \(heads)。"
    }

    private func goForward() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        AppHaptics.selection()
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
            id: UUID(),
            title: trimmedTitle,
            category: category,
            status: status,
            startAt: startAt,
            endAt: endAt,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressText: addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationNote: "",
            latitude: nil,
            longitude: nil,
            fee: normalizedFee,
            depositPaid: normalizedDeposit,
            deliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: ShootingAttribute.defaultSelection(for: category),
            crewAssignments: crewAssignments,
            reminderOffsets: BookingReminderOffset.defaultSelection,
            createdAt: .now,
            clientID: selectedClientID
        )

        store.upsert(booking: booking)

        if shouldCreateFollowUp {
            let dueAt = Calendar.current.date(byAdding: .day, value: -2, to: startAt) ?? startAt
            let reminder = TouchpointRecord(
                title: "\(trimmedTitle) 拍前确认",
                detailsText: "确认时间线、地点、联系人与交付要求。",
                dueAt: dueAt,
                channel: .wechat,
                priority: status == .tentative ? .high : .medium,
                clientID: selectedClientID,
                bookingID: booking.id,
                isSystemReminderEnabled: true,
                source: .systemPreShootConfirmation
            )
            store.upsert(touchpoint: reminder)
        }

        AppHaptics.success()
        dismiss()
    }

    private func applyStoreDefaultsIfNeeded() {
        guard venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        venue = store.settings.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        notesText = store.settings.defaultNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shiftEndDate(from oldValue: Date, to newValue: Date) {
        let duration = endAt.timeIntervalSince(oldValue)
        endAt = max(newValue.addingTimeInterval(duration), newValue.addingTimeInterval(1_800))
    }

    private static func normalizedStartDate(from date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if components.hour == 0 && components.minute == 0 {
            components.hour = 9
            components.minute = 0
        }
        return calendar.date(from: components) ?? date
    }

    private static func defaultTitle(for source: CreateBookingContext.Source) -> String {
        switch source {
        case .overview, .quickAction:
            return "新拍摄档期"
        case .schedule:
            return "当天拍摄档期"
        case .clientDetail:
            return "客户拍摄档期"
        case .team:
            return "团队拍摄档期"
        }
    }
}
