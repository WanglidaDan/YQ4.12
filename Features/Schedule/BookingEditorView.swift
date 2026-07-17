import AVFoundation
import Foundation
import Speech
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

private enum BookingSelectionSheet: Identifiable {
    case client
    case category
    case status

    var id: String {
        switch self {
        case .client: "client"
        case .category: "category"
        case .status: "status"
        }
    }

    var title: String {
        switch self {
        case .client: "关联客户"
        case .category: "拍摄类型"
        case .status: "状态"
        }
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
    @State private var selectionSheet: BookingSelectionSheet?
    @State private var saveErrorMessage: String?
    @State private var voiceErrorMessage: String?
    @State private var speechDraft = ""
    @State private var speechSuggestion = BookingSpeechSuggestion.empty
    @State private var speechService = BookingSpeechDraftService()
    @State private var showingQuickInput = false
    @State private var showingMoreDetails = false
    @State private var showingNewClient = false

    private let calendar = Calendar.current

    init(booking: BookingRecord?, initialStartAt: Date?, onSaved: ((BookingRecord) -> Void)?) {
        self.originalBooking = booking
        self.onSaved = onSaved

        let defaultStartAt = BookingDateDefaults.startDate(seedDate: initialStartAt)
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

    var body: some View {
        NavigationStack {
            Form {
                Section("档期") {
                    TextField("项目名称（可留空）", text: $title)

                    Button {
                        selectionSheet = .client
                    } label: {
                        LabeledContent("客户", value: selectedClientName)
                    }
                    .foregroundStyle(AppTheme.ink)

                    Picker("拍摄类型", selection: $category) {
                        ForEach(ServiceCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section("时间") {
                    DatePicker("开始", selection: $startAt)
                        .onChange(of: startAt) { oldValue, newValue in
                            shiftEndDate(from: oldValue, to: newValue)
                        }
                    DatePicker("结束", selection: $endAt, in: startAt...)
                }

                if showingMoreDetails {
                    Section("地点") {
                        TextField("场地", text: $venue)
                        TextField("城市 / 区域", text: $city)
                        TextField("详细地址", text: $addressText, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("到场备注", text: $locationNote, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("费用与交付") {
                        TextField("报价", value: $fee, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("定金", value: $depositPaid, format: .number)
                            .keyboardType(.decimalPad)
                        LabeledContent("待收", value: AppFormatters.currency(max(normalizedFee - normalizedDeposit, 0)))
                        TextField("交付内容", text: $deliverableText, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("状态与备注") {
                        Picker("状态", selection: $status) {
                            ForEach(BookingStatus.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        TextField("备注", text: $notesText, axis: .vertical)
                            .lineLimit(3...6)
                    }
                } else {
                    Section {
                        Button("更多信息", systemImage: "ellipsis.circle") {
                            withAnimation(.snappy) {
                                showingMoreDetails = true
                            }
                        }
                    }
                }

                Section {
                    Button(showingQuickInput ? "关闭语音填写" : "语音填写", systemImage: "mic") {
                        withAnimation(.snappy) {
                            showingQuickInput.toggle()
                        }
                    }
                }

                if showingQuickInput {
                    Section("语音填写") {
                        voicePanel
                        if speechDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                            speechResultPanel
                        }
                    }
                }

                if conflictBookings.isEmpty == false {
                    Section {
                        Label(conflictSummaryText, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(AppTheme.warning)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(originalBooking == nil ? "新建档期" : "编辑档期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        speechService.stopRecording()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark", action: saveTapped)
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectionSheet) { sheet in
                selectionSheetView(sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingNewClient) {
                ClientEditorView { savedClient in
                    selectedClientID = savedClient.id
                    selectionSheet = nil
                }
                .environment(store)
            }
            .onChange(of: speechService.transcript) { _, newValue in
                updateSpeechDraft(newValue)
            }
            .onDisappear {
                speechService.stopRecording()
            }
            .alert("保存失败", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if $0 == false { saveErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "档期没有保存成功。")
            }
            .alert("语音不可用", isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { if $0 == false { voiceErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { voiceErrorMessage = nil }
            } message: {
                Text(voiceErrorMessage ?? "请检查权限。")
            }
        }
    }

    private var voicePanel: some View {
        HStack(spacing: 12) {
            Image(systemName: speechService.isRecording ? "waveform" : "mic")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(speechService.isRecording ? "正在聆听" : "语音快速创建")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer(minLength: 0)

            Button(speechService.isRecording ? "停止" : "语音") {
                toggleSpeechDraft()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }

    private var speechResultPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $speechDraft)
                .font(.body.weight(.regular))
                .frame(minHeight: 74)
                .scrollContentBackground(.hidden)
                .onChange(of: speechDraft) { _, newValue in
                    reparseSpeechDraft(newValue)
                }

            HStack(spacing: 12) {
                Button("智能填充") {
                    applySpeechSuggestion()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(speechSuggestion.hasAnySuggestion ? AppTheme.accent : AppTheme.mutedInk, in: Capsule())
                .disabled(speechSuggestion.hasAnySuggestion == false)

                Button("清空") {
                    speechDraft = ""
                    speechSuggestion = .empty
                    speechService.transcript = ""
                }
                .font(.subheadline.weight(.regular))
                .foregroundStyle(AppTheme.secondaryInk)

                Spacer()
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
    }

    @ViewBuilder
    private func selectionSheetView(_ sheet: BookingSelectionSheet) -> some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    switch sheet {
                    case .client:
                        selectionButton(title: "暂不绑定", isSelected: selectedClientID == nil) {
                            selectedClientID = nil
                            selectionSheet = nil
                        }
                        rowDivider
                        selectionButton(title: "新建客户", systemImage: "person.crop.circle.badge.plus", isSelected: false) {
                            showingNewClient = true
                        }
                        ForEach(store.activeClients) { client in
                            rowDivider
                            selectionButton(title: client.name, isSelected: selectedClientID == client.id) {
                                selectedClientID = client.id
                                selectionSheet = nil
                            }
                        }
                    case .category:
                        ForEach(Array(ServiceCategory.allCases.enumerated()), id: \.element.id) { item in
                            if item.offset > 0 { rowDivider }
                            selectionButton(title: item.element.title, systemImage: item.element.symbolName, isSelected: category == item.element) {
                                category = item.element
                                selectionSheet = nil
                            }
                        }
                    case .status:
                        ForEach(Array(BookingStatus.allCases.enumerated()), id: \.element.id) { item in
                            if item.offset > 0 { rowDivider }
                            selectionButton(title: item.element.title, isSelected: status == item.element) {
                                status = item.element
                                selectionSheet = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectionSheet = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
        }
    }

    private func selectionButton(title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.regular))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 26)
                }
                Text(title)
                    .font(.body.weight(.regular))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedClientName: String {
        guard let selectedClientID, let client = store.client(id: selectedClientID) else { return "未选择" }
        return client.name
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedTitle: String {
        if trimmedTitle.isEmpty == false { return trimmedTitle }
        if let selectedClientID,
           let client = store.client(id: selectedClientID),
           client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "\(client.name) · \(category.title)"
        }
        let trimmedVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedVenue.isEmpty == false { return "\(trimmedVenue) · \(category.title)" }
        return "\(AppFormatters.shortDate(startAt)) \(category.title)"
    }

    private var normalizedFee: Double { max(fee, 0) }
    private var normalizedDeposit: Double { min(max(depositPaid, 0), normalizedFee) }

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
        if conflictBookings.count > 2 { return "该时间已有 \(heads) 等 \(conflictBookings.count) 个档期" }
        return heads.isEmpty ? "当前时间没有重叠档期" : "该时间已有 \(heads)"
    }

    private func toggleSpeechDraft() {
        Task { @MainActor in
            do {
                if speechService.isRecording {
                    speechService.stopRecording()
                    AppHaptics.selection()
                } else {
                    try await speechService.startRecording(localeIdentifier: "zh-CN")
                    AppHaptics.impactMedium()
                }
            } catch {
                voiceErrorMessage = error.localizedDescription
                AppHaptics.error()
            }
        }
    }

    private func updateSpeechDraft(_ value: String) {
        speechDraft = value
        reparseSpeechDraft(value)
    }

    private func reparseSpeechDraft(_ value: String) {
        speechSuggestion = BookingSpeechParser.parse(value, referenceDate: startAt, existingClients: store.activeClients)
    }

    private func applySpeechSuggestion() {
        if let matchedClientID = speechSuggestion.matchedClientID { selectedClientID = matchedClientID }
        if let suggestedCategory = speechSuggestion.category { category = suggestedCategory }
        if let suggestedStartAt = speechSuggestion.startAt {
            startAt = suggestedStartAt
            endAt = speechSuggestion.endAt ?? suggestedStartAt.addingTimeInterval(7_200)
        }
        if let suggestedVenue = speechSuggestion.venue, venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { venue = suggestedVenue }
        if let suggestedCity = speechSuggestion.city, city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { city = suggestedCity }
        if let suggestedAddress = speechSuggestion.addressText, addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addressText = suggestedAddress }
        if let suggestedFee = speechSuggestion.fee, fee <= 0 { fee = suggestedFee }
        if let suggestedDeposit = speechSuggestion.depositPaid, depositPaid <= 0 { depositPaid = min(suggestedDeposit, max(fee, suggestedDeposit)) }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { title = speechSuggestion.titleFallback(defaultCategory: category, defaultStartAt: startAt) }
        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           speechDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            notesText = speechDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        AppHaptics.success()
    }

    private func saveTapped() {
        guard store.canCurrentUserPerform(.manageBookings) else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "当前账号没有管理档期权限。"
            AppHaptics.error()
            return
        }
        speechService.stopRecording()
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
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "档期没有写入成功。"
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

private struct BookingSpeechSuggestion: Equatable {
    var matchedClientID: UUID?
    var clientName: String?
    var category: ServiceCategory?
    var startAt: Date?
    var endAt: Date?
    var city: String?
    var venue: String?
    var addressText: String?
    var fee: Double?
    var depositPaid: Double?

    static let empty = BookingSpeechSuggestion()

    var hasAnySuggestion: Bool {
        matchedClientID != nil || clientName != nil || category != nil || startAt != nil || city != nil || venue != nil || addressText != nil || fee != nil || depositPaid != nil
    }

    func titleFallback(defaultCategory: ServiceCategory, defaultStartAt: Date) -> String {
        if let clientName, clientName.isEmpty == false { return "\(clientName) · \((category ?? defaultCategory).title)" }
        if let venue, venue.isEmpty == false { return "\(venue) · \((category ?? defaultCategory).title)" }
        return "\(AppFormatters.shortDate(startAt ?? defaultStartAt)) \((category ?? defaultCategory).title)"
    }
}

private enum BookingSpeechParser {
    static func parse(_ text: String, referenceDate: Date, existingClients: [ClientRecord]) -> BookingSpeechSuggestion {
        let normalized = normalize(text)
        guard normalized.isEmpty == false else { return .empty }

        var suggestion = BookingSpeechSuggestion.empty
        suggestion.category = parseCategory(from: normalized)
        suggestion.startAt = parseDateTime(from: normalized, referenceDate: referenceDate)
        if let startAt = suggestion.startAt { suggestion.endAt = startAt.addingTimeInterval(TimeInterval(parseDurationMinutes(from: normalized) ?? 120) * 60) }
        suggestion.fee = parseAmount(from: normalized, markers: ["报价", "总价", "费用", "价格", "价钱"])
        suggestion.depositPaid = parseAmount(from: normalized, markers: ["定金", "订金", "已收", "先收"])

        if let matchedClient = matchExistingClient(in: normalized, existingClients: existingClients) {
            suggestion.matchedClientID = matchedClient.id
            suggestion.clientName = matchedClient.name
        } else {
            suggestion.clientName = parseClientName(from: normalized)
        }

        suggestion.city = parseCity(from: normalized)
        suggestion.venue = parseVenue(from: normalized)
        suggestion.addressText = parseAddress(from: normalized)
        return suggestion
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ",")
            .replacingOccurrences(of: "；", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: "礼拜", with: "星期")
            .replacingOccurrences(of: "周日", with: "星期日")
            .replacingOccurrences(of: "周天", with: "星期日")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCategory(from text: String) -> ServiceCategory? {
        let rules: [(ServiceCategory, [String])] = [
            (.wedding, ["婚礼", "婚宴", "接亲", "婚庆"]),
            (.portrait, ["写真", "肖像", "形象照", "证件照"]),
            (.family, ["亲子", "全家福", "家庭"]),
            (.children, ["儿童", "宝宝", "周岁"]),
            (.graduation, ["毕业", "毕业照"]),
            (.event, ["活动", "会议", "年会", "发布会", "跟拍", "纪实"]),
            (.video, ["视频", "短片", "摄像"]),
            (.commercial, ["商业", "广告", "宣传片"]),
            (.product, ["产品", "静物"]),
            (.food, ["美食", "菜品"]),
            (.space, ["空间", "建筑", "酒店", "民宿"])
        ]
        return rules.first { _, keywords in keywords.contains { text.localizedCaseInsensitiveContains($0) } }?.0
    }

    private static func parseDateTime(from text: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let referenceStart = calendar.startOfDay(for: referenceDate)
        var targetDay = referenceStart

        if text.contains("后天") {
            targetDay = calendar.date(byAdding: .day, value: 2, to: referenceStart) ?? referenceStart
        } else if text.contains("明天") || text.contains("明日") {
            targetDay = calendar.date(byAdding: .day, value: 1, to: referenceStart) ?? referenceStart
        } else if let weekday = parseWeekday(from: text, referenceDate: referenceDate) {
            targetDay = weekday
        }

        let time = parseHourMinute(from: text) ?? (10, 0)
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDay)
    }

    private static func parseWeekday(from text: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let weekdays: [(String, Int)] = [
            ("星期一", 2), ("星期二", 3), ("星期三", 4), ("星期四", 5), ("星期五", 6), ("星期六", 7), ("星期日", 1), ("星期天", 1),
            ("周一", 2), ("周二", 3), ("周三", 4), ("周四", 5), ("周五", 6), ("周六", 7), ("周末", 7)
        ]
        guard let weekday = weekdays.first(where: { text.contains($0.0) })?.1 else { return nil }
        let currentWeekday = calendar.component(.weekday, from: referenceDate)
        var delta = (weekday - currentWeekday + 7) % 7
        if text.contains("下周") || text.contains("下星期") {
            delta = delta == 0 ? 7 : delta + 7
        } else if delta == 0 {
            delta = 7
        }
        return calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: referenceDate))
    }

    private static func parseHourMinute(from text: String) -> (hour: Int, minute: Int)? {
        let pattern = "(上午|下午|晚上|傍晚|中午|早上|凌晨)?([零〇一二两三四五六七八九十0-9]{1,3})(点|:)(半|[零〇一二两三四五六七八九十0-9]{1,3})?"
        guard let result = match(text, pattern: pattern) else { return nil }
        let period = result[safe: 1] ?? ""
        let hourText = result[safe: 2] ?? ""
        let minuteText = result[safe: 4] ?? ""
        var hour = chineseNumber(hourText) ?? Int(hourText) ?? 10
        let minute = minuteText == "半" ? 30 : (chineseNumber(minuteText) ?? Int(minuteText) ?? 0)
        if ["下午", "晚上", "傍晚"].contains(period), hour < 12 { hour += 12 }
        if period == "中午", hour < 11 { hour += 12 }
        return (min(max(hour, 0), 23), min(max(minute, 0), 59))
    }

    private static func parseDurationMinutes(from text: String) -> Int? {
        if text.contains("半小时") { return 30 }
        if let match = match(text, pattern: "([零〇一二两三四五六七八九十0-9]{1,3})(个)?小时") {
            let hoursText = match[safe: 1] ?? ""
            if let hours = chineseNumber(hoursText) ?? Int(hoursText) { return max(hours, 1) * 60 }
        }
        return nil
    }

    private static func parseAmount(from text: String, markers: [String]) -> Double? {
        for marker in markers where text.contains(marker) {
            let tail = text.components(separatedBy: marker).dropFirst().joined(separator: marker)
            if let amount = parseFirstAmount(in: tail) { return amount }
        }
        return nil
    }

    private static func parseFirstAmount(in text: String) -> Double? {
        let head = text.components(separatedBy: CharacterSet(charactersIn: ",，。；; 定金订金已收先收预付押金"))[safe: 0] ?? text
        if let match = match(head, pattern: "([0-9]+(?:[.][0-9]+)?)(万|千|百)?") {
            guard let base = Double(match[safe: 1] ?? "") else { return nil }
            switch match[safe: 2] {
            case "万": return base * 10_000
            case "千": return base * 1_000
            case "百": return base * 100
            default: return base
            }
        }
        if let match = match(head, pattern: "([零〇一二两三四五六七八九十百千万]+)") {
            let value = chineseMoney(match[safe: 1] ?? "") ?? 0
            return value == 0 ? nil : Double(value)
        }
        return nil
    }

    private static func matchExistingClient(in text: String, existingClients: [ClientRecord]) -> ClientRecord? {
        existingClients
            .filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .sorted { $0.name.count > $1.name.count }
            .first { text.localizedCaseInsensitiveContains($0.name.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func parseClientName(from text: String) -> String? {
        if let match = match(text, pattern: "(?:客户|给|约了|联系)([一-龥]{1,4}(女士|先生|老师|总|姐|哥|同学)?)") {
            return match[safe: 1]?.nilIfBlank
        }
        if let match = match(text, pattern: "([一-龥]{1,4}(女士|先生|老师|总|姐|哥|同学))") {
            return match[safe: 1]?.nilIfBlank
        }
        return nil
    }

    private static func parseVenue(from text: String) -> String? {
        let markers = ["在", "地点", "场地", "地址", "去", "到"]
        let stopWords = ["报价", "总价", "费用", "价格", "价钱", "定金", "订金", "已收", "先收", "预付", "押金", "客户", "拍", "时长"]
        for marker in markers where text.contains(marker) {
            let tail = text.components(separatedBy: marker).dropFirst().joined(separator: marker)
            var candidate = tail.components(separatedBy: CharacterSet(charactersIn: ",，。；;"))[safe: 0] ?? tail
            for stop in stopWords {
                if let range = candidate.range(of: stop) {
                    candidate = String(candidate[..<range.lowerBound])
                }
            }
            let cleaned = candidate.replacingOccurrences(of: "拍摄", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 2 { return String(cleaned.prefix(24)) }
        }
        return nil
    }

    private static func parseCity(from text: String) -> String? {
        match(text, pattern: "([一-龥]{2,6}市)")?[safe: 1]
    }

    private static func parseAddress(from text: String) -> String? {
        guard text.contains("路") || text.contains("街") || text.contains("号") || text.contains("楼") || text.contains("区") else { return nil }
        return parseVenue(from: text)
    }

    private static func chineseNumber(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let value = Int(trimmed) { return value }
        return chineseMoney(trimmed)
    }

    private static func chineseMoney(_ raw: String) -> Int? {
        let text = raw.replacingOccurrences(of: "两", with: "二").replacingOccurrences(of: "〇", with: "零")
        if text.isEmpty { return nil }
        let digits: [Character: Int] = ["零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        if text.contains("万") {
            let parts = text.split(separator: "万", maxSplits: 1).map(String.init)
            return (chineseMoney(parts[safe: 0] ?? "") ?? 1) * 10_000 + (chineseMoney(parts[safe: 1] ?? "") ?? 0)
        }
        if text.contains("千") {
            let parts = text.split(separator: "千", maxSplits: 1).map(String.init)
            return (chineseMoney(parts[safe: 0] ?? "") ?? 1) * 1_000 + (chineseMoney(parts[safe: 1] ?? "") ?? 0)
        }
        if text.contains("百") {
            let parts = text.split(separator: "百", maxSplits: 1).map(String.init)
            return (chineseMoney(parts[safe: 0] ?? "") ?? 1) * 100 + (chineseMoney(parts[safe: 1] ?? "") ?? 0)
        }
        if text.contains("十") {
            let parts = text.split(separator: "十", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let high = parts[safe: 0]?.isEmpty == false ? (chineseMoney(parts[0]) ?? 1) : 1
            let low = chineseMoney(parts[safe: 1] ?? "") ?? 0
            return high * 10 + low
        }
        if text.count == 1, let first = text.first, let value = digits[first] { return value }
        return nil
    }

    private static func match(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<result.numberOfRanges).compactMap { index in
            let nsRange = result.range(at: index)
            guard nsRange.location != NSNotFound,
                  let range = Range(nsRange, in: text) else { return nil }
            return String(text[range])
        }
    }
}

@MainActor
@Observable
private final class BookingSpeechDraftService {
    var transcript = ""
    var isRecording = false

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    func startRecording(localeIdentifier: String) async throws {
        stopRecording()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw BookingSpeechDraftError.recognizerUnavailable
        }
        guard recognizer.isAvailable else {
            throw BookingSpeechDraftError.recognizerUnavailable
        }

        let speechStatus = await SFSpeechRecognizer.requestAuthorizationAsync()
        guard speechStatus == .authorized else {
            throw BookingSpeechDraftError.speechPermissionDenied
        }

        let microphoneGranted = await MicrophonePermission.request()
        guard microphoneGranted else {
            throw BookingSpeechDraftError.microphonePermissionDenied
        }

        speechRecognizer = recognizer
        transcript = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result { self?.transcript = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true { self?.stopRecording() }
            }
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private enum BookingSpeechDraftError: LocalizedError {
    case recognizerUnavailable
    case speechPermissionDenied
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "当前设备暂时无法使用中文语音识别。"
        case .speechPermissionDenied:
            return "请在系统设置中允许影期使用语音识别。"
        case .microphonePermissionDenied:
            return "请在系统设置中允许影期使用麦克风。"
        }
    }
}

private enum MicrophonePermission {
    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension SFSpeechRecognizer {
    static func requestAuthorizationAsync() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
