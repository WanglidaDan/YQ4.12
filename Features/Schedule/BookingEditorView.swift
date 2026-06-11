import SwiftUI

struct BookingEditorView: View {
    private let booking: BookingRecord?
    private let initialStartAt: Date?
    private let onSaved: ((BookingRecord) -> Void)?

    init(booking: BookingRecord? = nil, initialStartAt: Date? = nil, onSaved: ((BookingRecord) -> Void)? = nil) {
        self.booking = booking
        self.initialStartAt = initialStartAt
        self.onSaved = onSaved
    }

    var body: some View {
        BookingFormPage(booking: booking, initialStartAt: initialStartAt, onSaved: onSaved)
    }
}

private struct BookingFormPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private let originalBooking: BookingRecord?
    private let onSaved: ((BookingRecord) -> Void)?

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
    @State private var saveErrorMessage: String?

    private let calendar = Calendar.current

    init(booking: BookingRecord?, initialStartAt: Date?, onSaved: ((BookingRecord) -> Void)?) {
        self.originalBooking = booking
        self.onSaved = onSaved

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
    }

    private static func defaultStartDate(from seedDate: Date?) -> Date {
        guard let seedDate else { return .now }
        return Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: seedDate) ?? seedDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(originalBooking == nil ? "新建档期" : "编辑档期")
                            .font(.title2.weight(.bold))
                        Text("先把拍摄占住，客户、报价、地点都可以之后再补。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("快速信息") {
                    TextField("项目标题，不填会自动命名", text: $title)

                    Picker("关联客户", selection: $selectedClientID) {
                        Text("暂不绑定").tag(Optional<UUID>.none)
                        ForEach(store.activeClients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }

                    Picker("拍摄类型", selection: $category) {
                        ForEach(ServiceCategory.allCases) { item in
                            Label(item.title, systemImage: item.symbolName).tag(item)
                        }
                    }

                    Picker("状态", selection: $status) {
                        ForEach(BookingStatus.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section("时间") {
                    DatePicker("开始时间", selection: $startAt)
                        .onChange(of: startAt) { oldValue, newValue in
                            shiftEndDate(from: oldValue, to: newValue)
                        }
                    DatePicker("结束时间", selection: $endAt, in: startAt...)
                }

                Section("地点") {
                    TextField("城市 / 区域", text: $city)
                    TextField("场地", text: $venue)
                    TextField("详细地址", text: $addressText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("到场备注", text: $locationNote, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("报价交付") {
                    TextField("总报价", value: $fee, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.decimalPad)
                    TextField("已收金额", value: $depositPaid, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.decimalPad)
                    HStack {
                        Text("待收")
                        Spacer()
                        Text(AppFormatters.currency(max(normalizedFee - normalizedDeposit, 0)))
                            .font(.body.weight(.semibold))
                    }
                    TextField("交付内容", text: $deliverableText, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("项目说明", text: $notesText, axis: .vertical)
                        .lineLimit(2...6)
                }

                if conflictBookings.isEmpty == false {
                    Section {
                        Label(conflictSummaryText, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }
            }
            .navigationTitle(originalBooking == nil ? "新建档期" : "编辑档期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: saveTapped)
                        .fontWeight(.semibold)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if $0 == false { saveErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "档期没有保存成功，请稍后再试。")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedTitle: String {
        if trimmedTitle.isEmpty == false {
            return trimmedTitle
        }

        if let selectedClientID,
           let client = store.client(id: selectedClientID),
           client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "\(client.name) · \(category.title)"
        }

        let trimmedVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedVenue.isEmpty == false {
            return "\(trimmedVenue) · \(category.title)"
        }

        return "\(AppFormatters.shortDate(startAt)) \(category.title)"
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
        guard store.canCurrentUserPerform(.manageBookings) else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "当前账号没有新建或编辑档期的权限。请切换到工作区所有者，或在设置里调整成员权限。"
            AppHaptics.error()
            return
        }

        saveBooking()
    }

    private func saveBooking() {
        let booking = BookingRecord(
            id: originalBooking?.id ?? UUID(),
            title: resolvedTitle,
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
            shootingAttributes: originalBooking?.shootingAttributes ?? ShootingAttribute.defaultSelection(for: category),
            crewAssignments: originalBooking?.crewAssignments ?? [],
            reminderOffsets: originalBooking?.reminderOffsets ?? [],
            createdAt: originalBooking?.createdAt ?? .now,
            clientID: selectedClientID,
            isArchived: originalBooking?.isArchived ?? false,
            archivedAt: originalBooking?.archivedAt
        )

        store.upsert(booking: booking)

        guard store.booking(id: booking.id) != nil else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "档期没有写入成功，请检查当前账号是否有管理档期权限。"
            AppHaptics.error()
            return
        }

        if booking.reminderOffsets.isEmpty {
            AppNotificationManager.shared.removeBookingReminders(for: booking.id)
        }
        onSaved?(booking)
        AppHaptics.success()
        dismiss()
    }

    private func shiftEndDate(from oldValue: Date, to newValue: Date) {
        let duration = endAt.timeIntervalSince(oldValue)
        endAt = max(newValue.addingTimeInterval(duration), newValue.addingTimeInterval(1_800))
    }
}
