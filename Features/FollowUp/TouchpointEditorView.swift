import SwiftUI
import UIKit
import UserNotifications

struct TouchpointEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(StudioStore.self) private var store

    private let item: TouchpointRecord?

    @State private var title: String
    @State private var detailsText: String
    @State private var dueAt: Date
    @State private var channel: TouchpointChannel
    @State private var priority: TouchpointPriority
    @State private var selectedClientID: UUID?
    @State private var selectedBookingID: UUID?
    @State private var shouldScheduleSystemReminder: Bool
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    init(item: TouchpointRecord? = nil, prefilledClient: ClientRecord? = nil, prefilledBooking: BookingRecord? = nil) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _detailsText = State(initialValue: item?.detailsText ?? "")
        _dueAt = State(initialValue: item?.dueAt ?? .now.addingTimeInterval(86_400))
        _channel = State(initialValue: item?.channel ?? .wechat)
        _priority = State(initialValue: item?.priority ?? .medium)
        _selectedClientID = State(initialValue: item?.clientID ?? prefilledClient?.id ?? prefilledBooking?.clientID)
        _selectedBookingID = State(initialValue: item?.bookingID ?? prefilledBooking?.id)
        _shouldScheduleSystemReminder = State(initialValue: item?.isSystemReminderEnabled ?? true)
    }

    private var summaryText: String {
        if let bookingID = selectedBookingID, let booking = store.booking(id: bookingID) {
            return "关联项目：\(booking.title)"
        }
        if let clientID = selectedClientID, let client = store.client(id: clientID) {
            return "关联客户：\(client.name)"
        }
        return "当前未绑定客户或档期"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: item == nil ? "新增跟进" : "编辑跟进", titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
                AppCreateHeader(
                    eyebrow: item == nil ? "新增跟进" : "编辑跟进",
                    title: trimmedTitle.isEmpty ? "安排一条跟进" : trimmedTitle,
                    subtitle: summaryText,
                    systemImage: "checklist.checked"
                )

                AppEditorCard(title: "跟进信息") {
                    AppEditorLabeledField("标题") {
                        TextField("例如：拍前确认", text: $title)
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("内容") {
                        TextField("沟通重点、客户问题、下一步动作", text: $detailsText, axis: .vertical)
                            .lineLimit(4...)
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("截止时间") {
                        DatePicker("截止时间", selection: $dueAt)
                            .labelsHidden()
                    }
                }

                AppEditorCard(title: "方式与优先级") {
                    AppEditorLabeledField("方式") {
                        Picker("方式", selection: $channel) {
                            ForEach(TouchpointChannel.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("优先级") {
                        Picker("优先级", selection: $priority) {
                            ForEach(TouchpointPriority.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }

                    AppEditorDivider()

                    Toggle("系统通知提醒", isOn: $shouldScheduleSystemReminder)

                    if shouldScheduleSystemReminder {
                        notificationPermissionHint
                    } else {
                        AppInlineNote(systemImage: "bell.slash", text: "关闭后这条跟进只保留在应用内，不会向系统申请或安排通知。")
                    }
                }

                AppEditorCard(title: "关联对象") {
                    AppEditorLabeledField("客户") {
                        Picker("客户", selection: $selectedClientID) {
                            Text("暂不绑定").tag(Optional<UUID>.none)
                            ForEach(store.clients) { client in
                                Text(client.name).tag(Optional(client.id))
                            }
                        }
                    }

                    AppEditorDivider()

                    AppEditorLabeledField("相关档期") {
                        Picker("相关档期", selection: $selectedBookingID) {
                            Text("暂不绑定").tag(Optional<UUID>.none)
                            ForEach(filteredBookings) { booking in
                                Text(booking.title).tag(Optional(booking.id))
                            }
                        }
                    }

                    AppInlineNote(
                        systemImage: filteredBookings.isEmpty ? "calendar.badge.exclamationmark" : "link",
                        text: filteredBookings.isEmpty ? (selectedClientID == nil ? "当前还没有可关联的档期。" : "该客户暂时没有关联档期。") : "选择档期后会自动同步关联客户，避免保存出错。"
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                await refreshNotificationStatus()
            }
            .onChange(of: selectedClientID) { _, newValue in
                guard
                    let selectedBookingID,
                    let booking = store.booking(id: selectedBookingID)
                else { return }

                if booking.clientID != newValue {
                    self.selectedBookingID = nil
                }
            }
            .onChange(of: selectedBookingID) { _, newValue in
                guard
                    let newValue,
                    let booking = store.booking(id: newValue)
                else { return }

                if selectedClientID != booking.clientID {
                    selectedClientID = booking.clientID
                }
            }
            .onChange(of: shouldScheduleSystemReminder) { _, isEnabled in
                guard isEnabled else { return }
                Task { await refreshNotificationStatus() }
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
        }
    }

    @ViewBuilder
    private var notificationPermissionHint: some View {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            AppInlineNote(systemImage: "bell.badge", text: "已开启系统通知，保存后会按截止时间提醒你。")
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                AppInlineNote(systemImage: "bell.slash", text: "系统通知未开启，保存后不会收到提醒。", tint: AppTheme.warning)
                Button("打开系统设置") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
                .buttonStyle(.bordered)
            }
        case .notDetermined:
            AppInlineNote(systemImage: "bell", text: "只有在你开启这条提醒时，保存后才会请求系统通知权限。")
        @unknown default:
            AppInlineNote(systemImage: "bell", text: "系统通知状态暂不可用，保存后会尝试请求提醒权限。")
        }
    }

    private var filteredBookings: [BookingRecord] {
        let baseBookings: [BookingRecord]
        if let selectedClientID {
            baseBookings = store.bookings.filter { $0.clientID == selectedClientID }
        } else {
            baseBookings = store.bookings
        }

        return baseBookings.sorted { $0.startAt < $1.startAt }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let resolvedBooking: BookingRecord?
        if let selectedBookingID, let booking = store.booking(id: selectedBookingID) {
            if let selectedClientID, booking.clientID != selectedClientID {
                resolvedBooking = nil
            } else {
                resolvedBooking = booking
            }
        } else {
            resolvedBooking = nil
        }

        let resolvedClientID: UUID?
        if let resolvedBooking {
            resolvedClientID = resolvedBooking.clientID
        } else {
            resolvedClientID = selectedClientID
        }

        let draft = TouchpointRecord(
            id: item?.id ?? UUID(),
            title: trimmedTitle,
            detailsText: detailsText.trimmingCharacters(in: .whitespacesAndNewlines),
            dueAt: dueAt,
            channel: channel,
            priority: priority,
            isComplete: item?.isComplete ?? false,
            completedAt: item?.completedAt,
            createdAt: item?.createdAt ?? .now,
            clientID: resolvedClientID,
            bookingID: resolvedBooking?.id,
            isArchived: item?.isArchived ?? false,
            archivedAt: item?.archivedAt,
            isSystemReminderEnabled: shouldScheduleSystemReminder,
            source: item?.source ?? .manual
        )

        store.upsert(touchpoint: draft)
        AppHaptics.success()
        dismiss()
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await AppNotificationManager.shared.authorizationStatus()
    }
}
