import AVFoundation
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
    @State private var voiceErrorMessage: String?
    @State private var speechDraft = ""
    @State private var speechSuggestion = BookingSpeechSuggestion.empty
    @State private var speechService = BookingSpeechDraftService()

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

                voiceInputSection

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
                    Button("取消", role: .cancel) {
                        speechService.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: saveTapped)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: speechService.transcript) { _, newValue in
                speechDraft = newValue
                speechSuggestion = BookingSpeechParser.parse(
                    newValue,
                    referenceDate: startAt,
                    existingClients: store.activeClients
                )
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
                Text(saveErrorMessage ?? "档期没有保存成功，请稍后再试。")
            }
            .alert("语音输入不可用", isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { if $0 == false { voiceErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { voiceErrorMessage = nil }
            } message: {
                Text(voiceErrorMessage ?? "请检查麦克风和语音识别权限。")
            }
        }
    }

    private var voiceInputSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: speechService.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(speechService.isRecording ? AppTheme.warning : AppTheme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(speechService.isRecording ? "正在听你说档期" : "语音智能填充")
                            .font(.headline)
                        Text("例如：明天下午两点，王女士，亲子写真，万达影棚，报价一千二，定金三百。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(speechService.isRecording ? "停止" : "开始") {
                        toggleSpeechDraft()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                }

                if speechDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(speechDraft)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if speechSuggestion.hasAnySuggestion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("识别到这些信息")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(speechSuggestion.chips, id: \.self) { chip in
                                    Text(chip)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.accentSurface, in: Capsule())
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("智能填充") {
                            applySpeechSuggestion()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(speechSuggestion.hasAnySuggestion == false)

                        Button("填入标题") {
                            applySpeechDraftToTitle()
                        }
                        .buttonStyle(.bordered)

                        Button("追加到说明") {
                            appendSpeechDraftToNotes()
                        }
                        .buttonStyle(.bordered)

                        Button("清空") {
                            speechDraft = ""
                            speechSuggestion = .empty
                            speechService.transcript = ""
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("智能填充只会覆盖识别到的字段；识别不确定时，原来的表单内容会保留。")
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

    private func applySpeechSuggestion() {
        if let matchedClientID = speechSuggestion.matchedClientID {
            selectedClientID = matchedClientID
        }

        if let suggestedCategory = speechSuggestion.category {
            category = suggestedCategory
        }

        if let suggestedStartAt = speechSuggestion.startAt {
            let oldStartAt = startAt
            startAt = suggestedStartAt
            shiftEndDate(from: oldStartAt, to: suggestedStartAt)
        }

        if let suggestedVenue = speechSuggestion.venue, venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            venue = suggestedVenue
        }

        if let suggestedCity = speechSuggestion.city, city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            city = suggestedCity
        }

        if let suggestedAddress = speechSuggestion.addressText, addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addressText = suggestedAddress
        }

        if let suggestedFee = speechSuggestion.fee, fee <= 0 {
            fee = suggestedFee
        }

        if let suggestedDeposit = speechSuggestion.depositPaid, depositPaid <= 0 {
            depositPaid = min(suggestedDeposit, max(fee, suggestedDeposit))
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = speechSuggestion.titleFallback(defaultCategory: category, defaultStartAt: startAt)
        }

        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           speechDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            notesText = speechDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        AppHaptics.success()
    }

    private func applySpeechDraftToTitle() {
        let draft = speechDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty == false else { return }
        title = String(draft.prefix(36))
        AppHaptics.success()
    }

    private func appendSpeechDraftToNotes() {
        let draft = speechDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty == false else { return }
        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesText = draft
        } else {
            notesText += "\n" + draft
        }
        AppHaptics.success()
    }

    private func saveTapped() {
        guard store.canCurrentUserPerform(.manageBookings) else {
            saveErrorMessage = store.lastWorkspaceNoticeMessage ?? "当前账号没有新建或编辑档期的权限。请切换到工作区所有者，或在设置里调整成员权限。"
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

private struct BookingSpeechSuggestion: Equatable {
    var matchedClientID: UUID?
    var clientName: String?
    var category: ServiceCategory?
    var startAt: Date?
    var city: String?
    var venue: String?
    var addressText: String?
    var fee: Double?
    var depositPaid: Double?

    static let empty = BookingSpeechSuggestion()

    var hasAnySuggestion: Bool {
        matchedClientID != nil ||
        clientName != nil ||
        category != nil ||
        startAt != nil ||
        city != nil ||
        venue != nil ||
        addressText != nil ||
        fee != nil ||
        depositPaid != nil
    }

    var chips: [String] {
        var values: [String] = []
        if let clientName { values.append("客户：\(clientName)") }
        if let category { values.append("类型：\(category.title)") }
        if let startAt { values.append("时间：\(AppFormatters.shortDate(startAt)) \(AppFormatters.timeRange(start: startAt, end: startAt.addingTimeInterval(7_200)))") }
        if let venue { values.append("场地：\(venue)") }
        if let city { values.append("城市：\(city)") }
        if let fee { values.append("报价：\(AppFormatters.currency(fee))") }
        if let depositPaid { values.append("定金：\(AppFormatters.currency(depositPaid))") }
        return values
    }

    func titleFallback(defaultCategory: ServiceCategory, defaultStartAt: Date) -> String {
        let name = clientName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = category ?? defaultCategory
        if let name, name.isEmpty == false {
            return "\(name) · \(type.title)"
        }
        if let venue, venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "\(venue) · \(type.title)"
        }
        let date = startAt ?? defaultStartAt
        return "\(AppFormatters.shortDate(date)) \(type.title)"
    }
}

private enum BookingSpeechParser {
    static func parse(_ text: String, referenceDate: Date, existingClients: [ClientRecord]) -> BookingSpeechSuggestion {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return .empty }

        var suggestion = BookingSpeechSuggestion.empty
        suggestion.category = parseCategory(from: cleaned)
        suggestion.startAt = parseDateTime(from: cleaned, referenceDate: referenceDate)
        suggestion.fee = parseAmount(from: cleaned, markers: ["报价", "总价", "费用", "价格", "收"])
        suggestion.depositPaid = parseAmount(from: cleaned, markers: ["定金", "订金", "已收", "先收", "预付"])

        if let matchedClient = existingClients.first(where: { client in
            let name = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty == false && cleaned.localizedCaseInsensitiveContains(name)
        }) {
            suggestion.matchedClientID = matchedClient.id
            suggestion.clientName = matchedClient.name
        } else {
            suggestion.clientName = parseClientName(from: cleaned)
        }

        suggestion.venue = parseVenue(from: cleaned)
        suggestion.city = parseCity(from: cleaned)
        suggestion.addressText = parseAddress(from: cleaned)

        return suggestion
    }

    private static func parseCategory(from text: String) -> ServiceCategory? {
        let rules: [(ServiceCategory, [String])] = [
            (.wedding, ["婚礼", "婚宴", "接亲", "跟妆"]),
            (.engagement, ["求婚", "订婚"]),
            (.travel, ["旅拍", "旅行"]),
            (.portrait, ["写真", "肖像", "个人照", "形象照"]),
            (.couple, ["情侣", "双人"]),
            (.bestie, ["闺蜜"]),
            (.maternity, ["孕妇", "孕照"]),
            (.newborn, ["新生儿", "满月"]),
            (.children, ["儿童", "宝宝", "百天"]),
            (.family, ["亲子", "全家福", "家庭"]),
            (.graduation, ["毕业", "毕业照"]),
            (.pet, ["宠物", "猫", "狗"]),
            (.documentaryFilm, ["纪录片"]),
            (.aerial, ["航拍", "无人机"]),
            (.video, ["视频", "短片", "摄像"]),
            (.event, ["活动", "会议", "年会", "发布会", "展会"]),
            (.corporate, ["企业", "公司形象", "团队照"]),
            (.product, ["产品", "静物"]),
            (.ecommerce, ["电商", "服装", "服饰"]),
            (.food, ["美食", "餐饮", "菜品"]),
            (.space, ["空间", "建筑", "酒店", "民宿"]),
            (.commercial, ["商业", "广告"])
        ]

        return rules.first { _, keywords in
            keywords.contains { text.localizedCaseInsensitiveContains($0) }
        }?.0
    }

    private static func parseDateTime(from text: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)

        if text.contains("后天") {
            components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate)
        } else if text.contains("明天") || text.contains("明日") {
            components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate)
        } else if text.contains("今天") || text.contains("今日") {
            components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        } else if let explicitDate = match(text, pattern: "(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*[日号]?") {
            if explicitDate.count >= 3,
               let month = Int(explicitDate[1]),
               let day = Int(explicitDate[2]) {
                components.month = month
                components.day = day
                components.year = calendar.component(.year, from: referenceDate)
                if let candidate = calendar.date(from: components), candidate < calendar.startOfDay(for: referenceDate) {
                    components.year = (components.year ?? calendar.component(.year, from: referenceDate)) + 1
                }
            }
        }

        let hourMinute = parseHourMinute(from: text)
        components.hour = hourMinute.hour
        components.minute = hourMinute.minute
        components.second = 0

        return calendar.date(from: components)
    }

    private static func parseHourMinute(from text: String) -> (hour: Int, minute: Int) {
        let period = parsePeriod(from: text)
        if let match = match(text, pattern: "(\\d{1,2})\\s*[点:]\\s*(半|\\d{1,2})?") {
            var hour = Int(match[safe: 1] ?? "") ?? 10
            let minuteToken = match[safe: 2] ?? ""
            var minute = 0
            if minuteToken == "半" {
                minute = 30
            } else if let parsedMinute = Int(minuteToken) {
                minute = parsedMinute
            }

            if ["下午", "晚上", "傍晚"].contains(period), hour < 12 {
                hour += 12
            }
            if period == "中午", hour < 11 {
                hour += 12
            }
            if ["早上", "上午"].contains(period), hour == 12 {
                hour = 0
            }

            return (min(max(hour, 0), 23), min(max(minute, 0), 59))
        }

        return (10, 0)
    }

    private static func parsePeriod(from text: String) -> String {
        ["早上", "上午", "中午", "下午", "傍晚", "晚上"].first { text.contains($0) } ?? ""
    }

    private static func parseAmount(from text: String, markers: [String]) -> Double? {
        for marker in markers where text.contains(marker) {
            let tail = text.components(separatedBy: marker).dropFirst().joined(separator: marker)
            if let amount = parseFirstAmount(in: tail) {
                return amount
            }
        }
        return nil
    }

    private static func parseFirstAmount(in text: String) -> Double? {
        if let match = match(text, pattern: "(\\d+(?:\\.\\d+)?)\\s*(万|千|百)?") {
            guard let base = Double(match[safe: 1] ?? "") else { return nil }
            switch match[safe: 2] {
            case "万": return base * 10_000
            case "千": return base * 1_000
            case "百": return base * 100
            default: return base
            }
        }

        if text.contains("一千二") { return 1_200 }
        if text.contains("一千五") { return 1_500 }
        if text.contains("两千") { return 2_000 }
        if text.contains("三千") { return 3_000 }
        if text.contains("五千") { return 5_000 }
        if text.contains("三百") { return 300 }
        if text.contains("五百") { return 500 }
        if text.contains("八百") { return 800 }
        return nil
    }

    private static func parseClientName(from text: String) -> String? {
        if let match = match(text, pattern: "([\\p{Han}]{1,4}(女士|先生|老师|总|姐|哥))") {
            return match[safe: 1]
        }
        return nil
    }

    private static func parseVenue(from text: String) -> String? {
        let markers = ["在", "到", "去", "地点", "场地"]
        for marker in markers where text.contains(marker) {
            let tail = text.components(separatedBy: marker).dropFirst().joined(separator: marker)
            let cleaned = tail
                .components(separatedBy: CharacterSet(charactersIn: "，,。；;"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleaned, cleaned.count >= 2 {
                return String(cleaned.prefix(18))
            }
        }
        return nil
    }

    private static func parseCity(from text: String) -> String? {
        if let match = match(text, pattern: "([\\p{Han}]{2,6}市)") {
            return match[safe: 1]
        }
        return nil
    }

    private static func parseAddress(from text: String) -> String? {
        if text.contains("路") || text.contains("街") || text.contains("号") || text.contains("楼") {
            return parseVenue(from: text)
        }
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

        let microphoneGranted = await AVAudioSession.sharedInstance().requestRecordPermissionAsync()
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
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self?.stopRecording()
                }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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

private extension AVAudioSession {
    func requestRecordPermissionAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
