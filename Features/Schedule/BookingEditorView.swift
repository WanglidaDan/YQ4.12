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

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: speechService.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(speechService.isRecording ? AppTheme.warning : AppTheme.accent)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(speechService.isRecording ? "正在听你说档期" : "语音快速记录")
                                    .font(.headline)
                                Text("先说一整段安排，再一键填入标题或备注。")
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

                            HStack(spacing: 10) {
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
                                    speechService.transcript = ""
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("第一版先做语音草稿，避免自动识别错时间或金额；后续可升级为自动提取客户、时间、地点。")
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
