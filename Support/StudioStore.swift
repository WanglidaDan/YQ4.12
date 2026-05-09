import Foundation
import Observation
import UserNotifications
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@MainActor
@Observable
final class StudioStore {
    private let saveURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    @ObservationIgnored private var pendingPersistenceTask: Task<Void, Never>?
    @ObservationIgnored private var cloudSyncObserver: NSObjectProtocol?
    @ObservationIgnored private var paymentsByBookingID: [UUID: [PaymentRecord]] = [:]
    @ObservationIgnored private var paymentSummaryByBookingID: [UUID: PaymentComputation] = [:]
    @ObservationIgnored private var bookingsByClientID: [UUID: [BookingRecord]] = [:]
    @ObservationIgnored private var touchpointsByClientID: [UUID: [TouchpointRecord]] = [:]
    @ObservationIgnored private var analyticsDashboardCache: BusinessAnalyticsDashboard = .empty

    private static let systemManagedDepositNote = "系统初始化定金"

    private struct PaymentComputation: Sendable {
        var sortedRecords: [PaymentRecord] = []
        var refunds: Double = 0
        var positivePayments: Double = 0
        var received: Double = 0
        var hasBalancePayment: Bool = false

        static let empty = PaymentComputation()
    }

    enum ClientDeletionOutcome: Equatable {
        case deleted
        case archivedToPreserveHistory
    }

    var clients: [ClientRecord]
    var documents: [BusinessDocumentRecord]
    var attachments: [AttachmentRecord]
    var calendarLinks: [CalendarSyncLinkRecord]
    var bookings: [BookingRecord]
    var touchpoints: [TouchpointRecord]
    var payments: [PaymentRecord]
    var templates: [BookingTemplate]
    var settings: AppSettings
    var crewMembers: [CrewMemberRecord]
    var workspaceMembers: [WorkspaceMemberRecord]
    var collaborationSettings: WorkspaceCollaborationSettings
    var collaborationActivities: [CollaborationActivityRecord]
    var googleCalendarConnection: GoogleCalendarConnection
    var studioProfile: StudioProfile
    var authProfile: AuthProfile?
    var workspaceOwnerAppleUserID: String?
    var lastSyncIssueMessage: String?
    var lastWorkspaceNoticeMessage: String?
    var lastPersistenceIssueMessage: String?
    private(set) var lastPersistenceIssueAt: Date?
    private(set) var lastModifiedAt: Date
    private(set) var overviewSnapshot: OverviewSnapshot

    var isWorkspaceEmpty: Bool {
        activeClients.isEmpty && activeBookings.isEmpty && activeTouchpoints.isEmpty && activeDocuments.isEmpty && activeAttachments.isEmpty
    }

    var isAuthenticated: Bool {
        authProfile != nil
    }

    var activeClients: [ClientRecord] {
        clients.filter { $0.isArchived == false }
    }

    var archivedClients: [ClientRecord] {
        clients.filter(\.isArchived)
    }

    var activeBookings: [BookingRecord] {
        bookings.filter { $0.isArchived == false }
    }

    var archivedBookings: [BookingRecord] {
        bookings.filter(\.isArchived)
    }

    var activeTouchpoints: [TouchpointRecord] {
        touchpoints
            .filter { $0.isArchived == false && $0.isComplete == false }
            .sorted { $0.dueAt < $1.dueAt }
    }

    var archivedTouchpoints: [TouchpointRecord] {
        touchpoints.filter(\.isArchived)
    }

    var overdueTouchpoints: [TouchpointRecord] {
        touchpoints
            .filter { $0.isArchived == false && $0.isComplete == false && $0.dueAt < .now }
            .sorted { $0.dueAt < $1.dueAt }
    }

    init(fileManager: FileManager = .default, saveURL: URL? = nil) {
        self.fileManager = fileManager
        self.saveURL = saveURL ?? Self.defaultSaveURL(fileManager: fileManager)

        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        var loadedSnapshot = Self.migrate(snapshot: Self.loadSnapshot(
            at: self.saveURL,
            decoder: decoder,
            fileManager: fileManager
        ))

        if loadedSnapshot.settings.iCloudSyncEnabled,
           let remoteData = CloudSyncService.shared.loadRemoteSnapshotData(),
           let remoteSnapshot = try? decoder.decode(StudioStoreSnapshot.self, from: remoteData.data) {
            let migratedRemoteSnapshot = Self.migrate(snapshot: remoteSnapshot)
            if migratedRemoteSnapshot.lastModifiedAt > loadedSnapshot.lastModifiedAt {
                loadedSnapshot = migratedRemoteSnapshot
            }
        }

        clients = loadedSnapshot.clients
        documents = loadedSnapshot.documents
        attachments = loadedSnapshot.attachments
        calendarLinks = loadedSnapshot.calendarLinks
        bookings = loadedSnapshot.bookings
        touchpoints = loadedSnapshot.touchpoints
        payments = loadedSnapshot.payments
        templates = loadedSnapshot.templates.isEmpty ? Self.defaultTemplates() : loadedSnapshot.templates
        settings = loadedSnapshot.settings
        crewMembers = loadedSnapshot.crewMembers
        workspaceMembers = loadedSnapshot.workspaceMembers
        collaborationSettings = loadedSnapshot.collaborationSettings
        collaborationActivities = loadedSnapshot.collaborationActivities
        googleCalendarConnection = loadedSnapshot.googleCalendarConnection
        studioProfile = loadedSnapshot.studioProfile
        authProfile = loadedSnapshot.authProfile
        workspaceOwnerAppleUserID = loadedSnapshot.workspaceOwnerAppleUserID
        lastModifiedAt = loadedSnapshot.lastModifiedAt
        lastSyncIssueMessage = nil
        lastWorkspaceNoticeMessage = nil
        lastPersistenceIssueMessage = nil
        lastPersistenceIssueAt = nil
        AppFormatters.setCurrencyCode(loadedSnapshot.settings.currencyCode)
        overviewSnapshot = OverviewSnapshotBuilder(now: .now).build(
            clients: loadedSnapshot.clients,
            bookings: loadedSnapshot.bookings,
            touchpoints: loadedSnapshot.touchpoints,
            payments: loadedSnapshot.payments
        )
        reconcileWorkspaceMembershipIfNeeded()

        registerCloudSyncObserver()
        normalizeAndPersistIfNeeded(markModified: false)
        if settings.notificationsEnabled == false {
            AppNotificationManager.shared.removeAllManagedReminders(bookings: bookings, touchpoints: touchpoints)
        } else {
            refreshNotificationScheduling()
        }
    }

    static func defaultSaveURL(fileManager: FileManager = .default) -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "YingQi", directoryHint: .isDirectory)
        return (directory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appending(path: "studio-store.json")
    }

    deinit {
        if let cloudSyncObserver {
            NotificationCenter.default.removeObserver(cloudSyncObserver)
        }
    }

    func client(id: UUID) -> ClientRecord? {
        clients.first { $0.id == id }
    }

    func booking(id: UUID) -> BookingRecord? {
        bookings.first { $0.id == id }
    }

    func touchpoint(id: UUID) -> TouchpointRecord? {
        touchpoints.first { $0.id == id }
    }

    func client(for booking: BookingRecord) -> ClientRecord? {
        guard let clientID = booking.clientID else { return nil }
        return client(id: clientID)
    }

    func clientName(for booking: BookingRecord) -> String {
        client(for: booking)?.name ?? "未填写客户"
    }

    var preferredCrewMemberName: String? {
        guard settings.studioModeEnabled, settings.crewLensEnabled else { return nil }

        if let selectedMember = crewMembers.first(where: { $0.id == settings.currentCrewMemberID && $0.isArchived == false }) {
            return selectedMember.displayName
        }

        let explicitName = settings.currentMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        if explicitName.isEmpty == false {
            return explicitName
        }

        if let profileName = authProfile?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), profileName.isEmpty == false {
            return profileName
        }

        return nil
    }

    var activeCrewMemberNames: [String] {
        var seen: Set<String> = []

        let rosterNames = crewMembers
            .filter { $0.isArchived == false }
            .map(\.displayName)

        let bookingNames = activeBookings
            .flatMap(\.crewAssignments)
            .map(\.displayName)

        return (rosterNames + bookingNames)
            .filter { name in
                let key = Self.normalizedCrewMemberKey(name)
                guard key.isEmpty == false, seen.contains(key) == false else { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    func crewMember(id: UUID) -> CrewMemberRecord? {
        crewMembers.first { $0.id == id }
    }

    var activeCrewMembers: [CrewMemberRecord] {
        crewMembers
            .filter { $0.isArchived == false }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var currentSnapshotPayloadBytes: Int {
        guard let data = try? encoder.encode(currentSnapshot()) else { return 0 }
        return data.count
    }

    var canEnableICloudSync: Bool {
        currentSnapshotPayloadBytes <= CloudSyncService.maximumSnapshotBytes
    }

    var resolvedStudioProfile: StudioProfile {
        var profile = studioProfile
        if profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.displayName = settings.studioName
        }
        if profile.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.contactPhone = settings.contactPhone
        }
        return profile
    }

    func upsert(crewMember: CrewMemberRecord) {
        guard requirePermission(.manageWorkspace) else { return }
        if let index = crewMembers.firstIndex(where: { $0.id == crewMember.id }) {
            crewMembers[index] = crewMember
        } else {
            crewMembers.append(crewMember)
        }
        normalizeAndPersistIfNeeded()
    }

    func archiveCrewMember(_ crewMemberID: UUID) {
        guard requirePermission(.manageWorkspace) else { return }
        guard let index = crewMembers.firstIndex(where: { $0.id == crewMemberID }) else { return }
        crewMembers[index].isArchived = true
        normalizeAndPersistIfNeeded()
    }

    func restoreCrewMember(_ crewMemberID: UUID) {
        guard requirePermission(.manageWorkspace) else { return }
        guard let index = crewMembers.firstIndex(where: { $0.id == crewMemberID }) else { return }
        crewMembers[index].isArchived = false
        normalizeAndPersistIfNeeded()
    }

    func updateStudioProfile(_ profile: StudioProfile) {
        guard requirePermission(.manageWorkspace) else { return }
        var normalizedProfile = profile
        normalizedProfile.displayName = normalizedProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.contactPhone = AppFormatters.sanitizedPhoneNumber(normalizedProfile.contactPhone)
        normalizedProfile.contactEmail = normalizedProfile.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.legalName = normalizedProfile.legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.city = normalizedProfile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.address = normalizedProfile.address.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedProfile.notes = normalizedProfile.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        studioProfile = normalizedProfile
        settings.studioName = normalizedProfile.displayName
        settings.contactPhone = normalizedProfile.contactPhone
        normalizeAndPersistIfNeeded()
    }

    func assignments(for booking: BookingRecord, matching memberName: String?) -> [BookingCrewAssignment] {
        guard let memberName else { return [] }
        return BookingCrewAssignment.normalized(booking.crewAssignments).filter { $0.matches(memberName: memberName) }
    }

    func otherAssignments(for booking: BookingRecord, excluding memberName: String?) -> [BookingCrewAssignment] {
        let assignments = BookingCrewAssignment.normalized(booking.crewAssignments)
        guard let memberName else { return assignments }
        return assignments.filter { $0.matches(memberName: memberName) == false }
    }

    func bookings(on date: Date, assignedTo memberName: String, calendar: Calendar = .current, includeArchived: Bool = false) -> [BookingRecord] {
        bookings(on: date, calendar: calendar, includeArchived: includeArchived)
            .filter { assignments(for: $0, matching: memberName).isEmpty == false }
    }

    func bookings(for clientID: UUID, includeArchived: Bool = false) -> [BookingRecord] {
        let source = bookingsByClientID[clientID] ?? []
        return includeArchived ? source : source.filter { $0.isArchived == false }
    }

    func bookings(on date: Date, calendar: Calendar = .current, includeArchived: Bool = false) -> [BookingRecord] {
        let source = includeArchived ? bookings : activeBookings
        return source
            .filter { calendar.isDate($0.startAt, inSameDayAs: date) }
            .sorted { $0.startAt < $1.startAt }
    }

    func bookings(inMonthContaining date: Date, calendar: Calendar = .current, includeArchived: Bool = false) -> [BookingRecord] {
        let source = includeArchived ? bookings : activeBookings
        return source.filter {
            calendar.isDate($0.startAt, equalTo: date, toGranularity: .year) &&
            calendar.isDate($0.startAt, equalTo: date, toGranularity: .month)
        }
    }

    func upcomingBookings(within days: Int, from date: Date = .now, calendar: Calendar = .current) -> [BookingRecord] {
        let endDate = calendar.date(byAdding: .day, value: days, to: date) ?? date
        return activeBookings
            .filter { $0.startAt >= date && $0.startAt < endDate }
            .sorted { $0.startAt < $1.startAt }
    }

    func touchpoints(for clientID: UUID, includeArchived: Bool = false) -> [TouchpointRecord] {
        let source = touchpointsByClientID[clientID] ?? []
        return includeArchived ? source : source.filter { $0.isArchived == false }
    }

    func pendingTouchpoints(for clientID: UUID) -> [TouchpointRecord] {
        touchpoints(for: clientID).filter { $0.isComplete == false }
    }

    func nextPendingTouchpoint(for clientID: UUID) -> TouchpointRecord? {
        pendingTouchpoints(for: clientID).first
    }

    func payments(for bookingID: UUID) -> [PaymentRecord] {
        paymentsByBookingID[bookingID] ?? []
    }

    func hasManualPayments(for bookingID: UUID) -> Bool {
        payments(for: bookingID).contains { Self.isSystemManagedPayment($0) == false }
    }

    func paymentStatus(for booking: BookingRecord) -> PaymentStatus {
        let summary = paymentSummary(for: booking.id)

        if summary.refunds > 0 && summary.received == 0 {
            return .refunded
        }
        if summary.received <= 0 {
            return .unpaidDeposit
        }
        if summary.received >= booking.fee {
            return .paidInFull
        }

        return summary.hasBalancePayment ? .balanceDue : .depositReceived
    }

    func receivedAmount(for booking: BookingRecord) -> Double {
        paymentSummary(for: booking.id).received
    }

    func outstandingAmount(for booking: BookingRecord) -> Double {
        max(booking.fee - paymentSummary(for: booking.id).received, 0)
    }

    func lifetimeValue(for clientID: UUID) -> Double {
        bookings(for: clientID).reduce(0) { $0 + $1.fee }
    }

    func outstandingValue(for clientID: UUID) -> Double {
        bookings(for: clientID).reduce(0) { result, booking in
            result + outstandingAmount(for: booking)
        }
    }

    func monthlyIncome(at date: Date = .now, calendar: Calendar = .current) -> Double {
        bookings(inMonthContaining: date, calendar: calendar).reduce(0) { $0 + $1.fee }
    }

    func monthlyOutstanding(at date: Date = .now, calendar: Calendar = .current) -> Double {
        bookings(inMonthContaining: date, calendar: calendar).reduce(0) { $0 + outstandingAmount(for: $1) }
    }

    func recentOutstandingBookings(limit: Int = 3) -> [BookingRecord] {
        activeBookings
            .filter { outstandingAmount(for: $0) > 0 && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
            .prefix(limit)
            .map(\.self)
    }

    func pendingDeliveryBookings(limit: Int = 10) -> [BookingRecord] {
        activeBookings
            .filter { $0.status == .editing }
            .sorted { $0.startAt < $1.startAt }
            .prefix(limit)
            .map(\.self)
    }

    func pendingConfirmationBookings(limit: Int = 10) -> [BookingRecord] {
        activeBookings
            .filter { $0.status == .tentative || $0.status == .inquiry }
            .sorted { $0.startAt < $1.startAt }
            .prefix(limit)
            .map(\.self)
    }

    func bookingsNeedingConfirmationSheet(limit: Int = 10) -> [BookingRecord] {
        activeBookings
            .filter { booking in
                booking.status == .confirmed &&
                touchpoints.contains(where: {
                    $0.bookingID == booking.id &&
                    $0.isArchived == false &&
                    $0.title.localizedCaseInsensitiveContains("确认")
                }) == false
            }
            .sorted { $0.startAt < $1.startAt }
            .prefix(limit)
            .map(\.self)
    }

    func recentBookedAt(for clientID: UUID) -> Date? {
        bookings(for: clientID)
            .filter { [.confirmed, .shooting, .editing, .delivered].contains($0.status) }
            .map(\.startAt)
            .max()
    }

    func orderCount(for clientID: UUID) -> Int {
        bookingsByClientID[clientID]?.lazy.filter { $0.isArchived == false }.count ?? 0
    }

    func updateSettings(_ settings: AppSettings) {
        guard requirePermission(.manageWorkspace) else { return }
        let wasSyncEnabled = self.settings.iCloudSyncEnabled
        var normalizedSettings = settings
        normalizedSettings.currencyCode = AppSettings.normalizedCurrencyCode(normalizedSettings.currencyCode)

        if isAuthenticated == false {
            normalizedSettings.iCloudSyncEnabled = false
        }

        if normalizedSettings.studioModeEnabled == false {
            normalizedSettings.crewLensEnabled = false
            normalizedSettings.currentCrewMemberID = nil
            normalizedSettings.currentMemberName = ""
        }

        if let currentCrewMemberID = normalizedSettings.currentCrewMemberID,
           crewMembers.contains(where: { $0.id == currentCrewMemberID && $0.isArchived == false }) == false {
            normalizedSettings.currentCrewMemberID = nil
        }

        if normalizedSettings.currentCrewMemberID != nil {
            normalizedSettings.currentMemberName = ""
        }

        if normalizedSettings.studioName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedSettings.studioName = studioProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if normalizedSettings.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedSettings.contactPhone = AppFormatters.sanitizedPhoneNumber(studioProfile.contactPhone)
        }

        self.settings = normalizedSettings
        AppFormatters.setCurrencyCode(normalizedSettings.currencyCode)

        if normalizedSettings.iCloudSyncEnabled && CloudSyncService.shared.isAvailable == false {
            self.settings.iCloudSyncEnabled = false
            lastSyncIssueMessage = "当前设备未检测到可用的 iCloud 账户，请先确认系统 iCloud 状态后再开启同步。"
        } else if normalizedSettings.iCloudSyncEnabled && canEnableICloudSync == false {
            self.settings.iCloudSyncEnabled = false
            lastSyncIssueMessage = "当前工作区数据量已接近 iCloud 轻量同步上限，请先归档或导出历史数据后再开启同步。"
        } else if canEnableICloudSync {
            lastSyncIssueMessage = nil
        }

        if wasSyncEnabled == false, self.settings.iCloudSyncEnabled {
            adoptRemoteSnapshotIfNeeded()
        }

        refreshNotificationScheduling()
        normalizeAndPersistIfNeeded()
    }

    func setAuthProfile(_ authProfile: AuthProfile) {
        guard requirePermission(.manageWorkspace) || workspaceMembers.isEmpty else { return }
        if let workspaceOwnerAppleUserID, workspaceOwnerAppleUserID != authProfile.appleUserID {
            startIsolatedWorkspace(for: authProfile)
            return
        }

        self.authProfile = authProfile
        if workspaceOwnerAppleUserID == nil {
            workspaceOwnerAppleUserID = authProfile.appleUserID
        }
        normalizeAndPersistIfNeeded()
    }

    func clearAuthProfile() {
        guard requirePermission(.manageWorkspace) || workspaceMembers.isEmpty else { return }
        authProfile = nil
        settings.iCloudSyncEnabled = false
        normalizeAndPersistIfNeeded()
    }

    @discardableResult
    func importSampleDataIfEmpty(now: Date = .now) -> Bool {
        guard requirePermission(.manageWorkspace) || workspaceMembers.isEmpty else { return false }
        guard isWorkspaceEmpty else { return false }
        var snapshot = SampleDataSeeder.makeSnapshot(now: now)
        snapshot.templates = templates
        snapshot.settings = settings
        snapshot.workspaceMembers = workspaceMembers
        snapshot.collaborationSettings = collaborationSettings
        snapshot.collaborationActivities = collaborationActivities
        snapshot.googleCalendarConnection = googleCalendarConnection
        snapshot.authProfile = authProfile
        snapshot.workspaceOwnerAppleUserID = workspaceOwnerAppleUserID ?? authProfile?.appleUserID
        apply(snapshot: snapshot)
        return true
    }

    func clearAllData() {
        guard requirePermission(.manageWorkspace) else { return }
        purgeAttachmentStorage()
        apply(snapshot: StudioStoreSnapshot(
            clients: [],
            documents: [],
            attachments: [],
            calendarLinks: [],
            workspaceMembers: workspaceMembers,
            collaborationSettings: collaborationSettings,
            collaborationActivities: [],
            googleCalendarConnection: googleCalendarConnection.redactedForPersistence,
            bookings: [],
            touchpoints: [],
            payments: [],
            crewMembers: crewMembers,
            studioProfile: studioProfile,
            templates: templates,
            settings: settings,
            authProfile: authProfile,
            workspaceOwnerAppleUserID: workspaceOwnerAppleUserID,
            lastModifiedAt: .now
        ))
    }

    func deleteAccountAndWorkspace() {
        guard requirePermission(.manageWorkspace) || workspaceMembers.isEmpty else { return }

        let shouldClearCloud = settings.iCloudSyncEnabled
        purgeAttachmentStorage()
        AppNotificationManager.shared.removeAllManagedReminders(bookings: bookings, touchpoints: touchpoints)

        var emptySettings = AppSettings.default
        emptySettings.themeStyle = settings.themeStyle
        emptySettings.currencyCode = settings.currencyCode

        let emptySnapshot = StudioStoreSnapshot(
            clients: [],
            documents: [],
            attachments: [],
            calendarLinks: [],
            workspaceMembers: [],
            collaborationSettings: .default,
            collaborationActivities: [],
            googleCalendarConnection: .empty,
            bookings: [],
            touchpoints: [],
            payments: [],
            crewMembers: [],
            studioProfile: .empty,
            templates: Self.defaultTemplates(),
            settings: emptySettings,
            authProfile: nil,
            workspaceOwnerAppleUserID: nil,
            lastModifiedAt: .now
        )

        if shouldClearCloud, let data = try? encoder.encode(emptySnapshot) {
            try? CloudSyncService.shared.push(snapshotData: data, lastModifiedAt: emptySnapshot.lastModifiedAt)
        }

        apply(snapshot: emptySnapshot, markModified: false)
    }

    func upsert(client: ClientRecord) {
        guard requirePermission(.manageClients) else { return }
        let isExisting = clients.contains { $0.id == client.id }
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
        } else {
            clients.append(client)
        }
        if client.stageMode == .automatic {
            recomputeClientStage(for: client.id)
        }
        appendActivity(actionTitle: isExisting ? "更新客户" : "新建客户", target: .client, targetID: client.id.uuidString, summary: client.name)
        normalizeAndPersistIfNeeded()
    }

    func upsert(booking: BookingRecord) {
        guard requirePermission(.manageBookings) else { return }
        let isExisting = bookings.contains { $0.id == booking.id }
        let previousClientID = bookings.first(where: { $0.id == booking.id })?.clientID
        let syncedBooking = synchronizedBookingPaymentState(for: booking)

        if let index = bookings.firstIndex(where: { $0.id == syncedBooking.id }) {
            bookings[index] = syncedBooking
        } else {
            bookings.append(syncedBooking)
        }

        if let previousClientID {
            recomputeClientStage(for: previousClientID)
        }
        if let clientID = syncedBooking.clientID {
            recomputeClientStage(for: clientID)
        }

        appendActivity(actionTitle: isExisting ? "更新订单" : "新建订单", target: .booking, targetID: syncedBooking.id.uuidString, summary: syncedBooking.title)
        normalizeAndPersistIfNeeded()
        scheduleBookingReminderIfEnabled(for: syncedBooking)
    }

    func upsert(touchpoint: TouchpointRecord) {
        guard requirePermission(.manageFollowUps) else { return }
        let isExisting = touchpoints.contains { $0.id == touchpoint.id }
        let previousClientID = touchpoints.first(where: { $0.id == touchpoint.id })?.clientID

        if let index = touchpoints.firstIndex(where: { $0.id == touchpoint.id }) {
            touchpoints[index] = touchpoint
        } else {
            touchpoints.append(touchpoint)
        }

        if let previousClientID {
            refreshClientFollowUpDates(for: previousClientID)
        }
        if let clientID = touchpoint.clientID {
            refreshClientFollowUpDates(for: clientID)
        }

        appendActivity(actionTitle: isExisting ? "更新跟进" : "新建跟进", target: .touchpoint, targetID: touchpoint.id.uuidString, summary: touchpoint.title)
        normalizeAndPersistIfNeeded()
        scheduleTouchpointReminderIfEnabled(for: touchpoint)
    }

    func upsert(payment: PaymentRecord) {
        guard requirePermission(.managePayments) else { return }
        let isExisting = payments.contains { $0.id == payment.id }
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index] = payment
        } else {
            payments.append(payment)
        }

        refreshBookingPaymentCache(for: payment.bookingID)
        appendActivity(actionTitle: isExisting ? "更新回款" : "新增回款", target: .payment, targetID: payment.id.uuidString, summary: AppFormatters.currency(payment.amount))
        normalizeAndPersistIfNeeded()
    }

    func deletePayment(_ paymentID: UUID) {
        guard requirePermission(.managePayments) else { return }
        guard let payment = payments.first(where: { $0.id == paymentID }) else { return }
        let bookingID = payment.bookingID
        payments.removeAll { $0.id == paymentID }
        refreshBookingPaymentCache(for: bookingID)
        appendActivity(actionTitle: "删除回款", target: .payment, targetID: paymentID.uuidString, summary: AppFormatters.currency(payment.amount))
        normalizeAndPersistIfNeeded()
    }

    func markTouchpointComplete(_ touchpointID: UUID, on date: Date = .now) {
        guard requirePermission(.manageFollowUps) else { return }
        guard let index = touchpoints.firstIndex(where: { $0.id == touchpointID }) else { return }
        touchpoints[index].markCompleted(on: date)

        if let clientID = touchpoints[index].clientID {
            if let clientIndex = clients.firstIndex(where: { $0.id == clientID }) {
                clients[clientIndex].lastContactAt = date
            }
            refreshClientFollowUpDates(for: clientID)
        }

        normalizeAndPersistIfNeeded()
        AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.touchpointIdentifier(for: touchpointID))
        AppHaptics.success()
    }

    func snoozeTouchpoint(_ touchpointID: UUID, byDays days: Int = 1) {
        guard requirePermission(.manageFollowUps) else { return }
        guard let index = touchpoints.firstIndex(where: { $0.id == touchpointID }) else { return }
        let referenceDate = touchpoints[index].dueAt < .now ? Date.now : touchpoints[index].dueAt
        touchpoints[index].dueAt = Calendar.current.date(byAdding: .day, value: days, to: referenceDate) ?? referenceDate
        touchpoints[index].isComplete = false
        touchpoints[index].completedAt = nil

        if let clientID = touchpoints[index].clientID {
            refreshClientFollowUpDates(for: clientID)
        }

        normalizeAndPersistIfNeeded()
        if let refreshed = touchpoint(id: touchpointID) {
            scheduleTouchpointReminderIfEnabled(for: refreshed)
        }
        AppHaptics.warning()
    }

    func reopenTouchpoint(_ touchpointID: UUID, nextDueAt: Date? = nil) {
        guard requirePermission(.manageFollowUps) else { return }
        guard let index = touchpoints.firstIndex(where: { $0.id == touchpointID }) else { return }
        touchpoints[index].isComplete = false
        touchpoints[index].completedAt = nil
        if let nextDueAt {
            touchpoints[index].dueAt = nextDueAt
        } else if touchpoints[index].dueAt < .now {
            touchpoints[index].dueAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        }

        if let clientID = touchpoints[index].clientID {
            refreshClientFollowUpDates(for: clientID)
        }

        normalizeAndPersistIfNeeded()
        if let refreshed = touchpoint(id: touchpointID) {
            scheduleTouchpointReminderIfEnabled(for: refreshed)
        }
        AppHaptics.warning()
    }

    func archiveClient(_ clientID: UUID) {
        guard requirePermission(.manageClients) else { return }
        guard let index = clients.firstIndex(where: { $0.id == clientID }) else { return }
        clients[index].isArchived = true
        clients[index].archivedAt = .now
        appendActivity(actionTitle: "归档客户", target: .client, targetID: clientID.uuidString, summary: clients[index].name)
        normalizeAndPersistIfNeeded()
    }

    func restoreClient(_ clientID: UUID) {
        guard requirePermission(.manageClients) else { return }
        guard let index = clients.firstIndex(where: { $0.id == clientID }) else { return }
        clients[index].isArchived = false
        clients[index].archivedAt = nil
        normalizeAndPersistIfNeeded()
    }

    func archiveBooking(_ bookingID: UUID) {
        guard requirePermission(.manageBookings) else { return }
        guard let index = bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        let clientID = bookings[index].clientID
        bookings[index].isArchived = true
        bookings[index].archivedAt = .now
        AppNotificationManager.shared.removeBookingReminders(for: bookingID)
        recomputeClientStageIfNeeded(for: clientID)
        appendActivity(actionTitle: "归档订单", target: .booking, targetID: bookingID.uuidString, summary: bookings[index].title)
        normalizeAndPersistIfNeeded()
    }

    func restoreBooking(_ bookingID: UUID) {
        guard requirePermission(.manageBookings) else { return }
        guard let index = bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        bookings[index].isArchived = false
        bookings[index].archivedAt = nil
        recomputeClientStageIfNeeded(for: bookings[index].clientID)
        normalizeAndPersistIfNeeded()
        scheduleBookingReminderIfEnabled(for: bookings[index])
    }

    func archiveTouchpoint(_ touchpointID: UUID) {
        guard requirePermission(.manageFollowUps) else { return }
        guard let index = touchpoints.firstIndex(where: { $0.id == touchpointID }) else { return }
        let clientID = touchpoints[index].clientID
        touchpoints[index].isArchived = true
        touchpoints[index].archivedAt = .now
        AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.touchpointIdentifier(for: touchpointID))
        if let clientID {
            refreshClientFollowUpDates(for: clientID)
        }
        appendActivity(actionTitle: "归档跟进", target: .touchpoint, targetID: touchpointID.uuidString, summary: touchpoints[index].title)
        normalizeAndPersistIfNeeded()
    }

    func restoreTouchpoint(_ touchpointID: UUID) {
        guard requirePermission(.manageFollowUps) else { return }
        guard let index = touchpoints.firstIndex(where: { $0.id == touchpointID }) else { return }
        let clientID = touchpoints[index].clientID
        touchpoints[index].isArchived = false
        touchpoints[index].archivedAt = nil
        if let clientID {
            refreshClientFollowUpDates(for: clientID)
        }
        normalizeAndPersistIfNeeded()
        scheduleTouchpointReminderIfEnabled(for: touchpoints[index])
    }

    @discardableResult
    func deleteClient(_ clientID: UUID) -> ClientDeletionOutcome {
        guard requirePermission(.manageClients) else { return .archivedToPreserveHistory }
        let hasHistory = bookings.contains { $0.clientID == clientID } || touchpoints.contains { $0.clientID == clientID }
        if hasHistory {
            archiveClient(clientID)
            return .archivedToPreserveHistory
        }

        clients.removeAll { $0.id == clientID }
        normalizeAndPersistIfNeeded()
        AppHaptics.error()
        return .deleted
    }

    func deleteBooking(_ bookingID: UUID) {
        guard requirePermission(.manageBookings) else { return }
        let bookingTitle = bookings.first(where: { $0.id == bookingID })?.title ?? "订单"
        let clientID = bookings.first(where: { $0.id == bookingID })?.clientID
        bookings.removeAll { $0.id == bookingID }
        payments.removeAll { $0.bookingID == bookingID }
        touchpoints.indices.forEach { index in
            if touchpoints[index].bookingID == bookingID {
                touchpoints[index].bookingID = nil
            }
        }
        removeOrphanedTouchpoints()
        AppNotificationManager.shared.removeBookingReminders(for: bookingID)
        if let clientID {
            recomputeClientStage(for: clientID)
        }
        appendActivity(actionTitle: "删除订单", target: .booking, targetID: bookingID.uuidString, summary: bookingTitle)
        normalizeAndPersistIfNeeded()
        AppHaptics.error()
    }

    func deleteTouchpoint(_ touchpointID: UUID) {
        guard requirePermission(.manageFollowUps) else { return }
        let touchpointTitle = touchpoints.first(where: { $0.id == touchpointID })?.title ?? "跟进"
        let clientID = touchpoints.first(where: { $0.id == touchpointID })?.clientID
        touchpoints.removeAll { $0.id == touchpointID }
        AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.touchpointIdentifier(for: touchpointID))
        if let clientID {
            refreshClientFollowUpDates(for: clientID)
        }
        appendActivity(actionTitle: "删除跟进", target: .touchpoint, targetID: touchpointID.uuidString, summary: touchpointTitle)
        normalizeAndPersistIfNeeded()
        AppHaptics.error()
    }

    func exportJSON() throws -> URL {
        guard requirePermission(.exportData) else { throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有导出权限。") }
        return try StoreExportService.writeJSON(snapshot: currentSnapshot(), to: exportDirectory)
    }

    func exportCSV() throws -> URL {
        guard requirePermission(.exportData) else { throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有导出权限。") }
        return try StoreExportService.writeCSV(
            clients: clients,
            bookings: bookings,
            touchpoints: touchpoints,
            payments: payments,
            to: exportDirectory
        )
    }

    func createBackup() throws -> URL {
        guard requirePermission(.exportData) else { throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有备份权限。") }
        return try StoreExportService.writeBackupPackage(
            snapshot: currentSnapshot(),
            attachmentsDirectory: attachmentsDirectoryURL,
            to: backupDirectory
        )
    }

    func restore(from url: URL) throws {
        guard requirePermission(.manageWorkspace) else { throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有恢复权限。") }
        let payload = try loadBackupPayload(from: url)
        var snapshot = Self.migrate(snapshot: try decoder.decode(StudioStoreSnapshot.self, from: payload.snapshotData))

        if let authProfile {
            if let restoredOwner = snapshot.workspaceOwnerAppleUserID,
               restoredOwner != authProfile.appleUserID {
                snapshot.settings.iCloudSyncEnabled = false
            }
            snapshot.authProfile = authProfile
            snapshot.workspaceOwnerAppleUserID = authProfile.appleUserID
        } else {
            snapshot.authProfile = nil
            snapshot.workspaceOwnerAppleUserID = nil
            snapshot.settings.iCloudSyncEnabled = false
        }

        let restoredAttachments = try preparedRestoredAttachmentsDirectory(from: payload.attachmentsDirectoryURL)
        if let restoredAttachments {
            try replaceAttachmentsDirectory(withPreparedContentsAt: restoredAttachments)
        } else {
            purgeAttachmentStorage()
        }
        apply(snapshot: snapshot)
    }

    private var exportDirectory: URL {
        fileManager.temporaryDirectory.appending(path: "YingQiExports", directoryHint: .isDirectory)
    }

    private var backupDirectory: URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "YingQiBackups", directoryHint: .isDirectory)
        return directory ?? fileManager.temporaryDirectory.appending(path: "YingQiBackups", directoryHint: .isDirectory)
    }

    private func synchronizedBookingPaymentState(for booking: BookingRecord) -> BookingRecord {
        var draft = booking
        let existingPayments = payments(for: booking.id)
        let manualPayments = existingPayments.filter { Self.isSystemManagedPayment($0) == false }

        if manualPayments.isEmpty {
            payments.removeAll { $0.bookingID == booking.id && Self.isSystemManagedPayment($0) }
            if draft.depositPaid > 0 {
                payments.append(Self.makeSystemManagedDepositPayment(for: draft, amount: draft.depositPaid))
            }
        }

        draft.depositPaid = receivedAmount(for: draft)
        return draft
    }

    private static func makeSystemManagedDepositPayment(for booking: BookingRecord, amount: Double) -> PaymentRecord {
        PaymentRecord(
            bookingID: booking.id,
            amount: max(amount, 0),
            paymentType: .deposit,
            date: min(booking.startAt, .now),
            note: systemManagedDepositNote
        )
    }

    private static func isSystemManagedPayment(_ payment: PaymentRecord) -> Bool {
        [systemManagedDepositNote, "历史定金迁移"].contains(payment.note)
    }

    private func refreshBookingPaymentCache(for bookingID: UUID) {
        guard let index = bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        bookings[index].depositPaid = receivedAmount(for: bookings[index])
    }

    private func refreshClientFollowUpDates(for clientID: UUID) {
        guard let clientIndex = clients.firstIndex(where: { $0.id == clientID }) else { return }

        let pending = touchpoints
            .filter { $0.clientID == clientID && $0.isArchived == false && $0.isComplete == false }
            .sorted { $0.dueAt < $1.dueAt }

        let completed = touchpoints
            .filter { $0.clientID == clientID && $0.isArchived == false && $0.isComplete }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        clients[clientIndex].nextContactAt = pending.first?.dueAt
        if let latestCompletedAt = completed.first?.completedAt,
           latestCompletedAt > (clients[clientIndex].lastContactAt ?? .distantPast) {
            clients[clientIndex].lastContactAt = latestCompletedAt
        }
    }

    private func recomputeClientStage(for clientID: UUID) {
        guard let index = clients.firstIndex(where: { $0.id == clientID }) else { return }
        guard clients[index].stageMode == .automatic else { return }
        let relatedBookings = bookings.filter { $0.clientID == clientID && $0.isArchived == false }
        clients[index].stage = suggestedLeadStage(for: relatedBookings)
    }

    private func recomputeClientStageIfNeeded(for clientID: UUID?) {
        guard let clientID else { return }
        recomputeClientStage(for: clientID)
    }

    private func adoptRemoteSnapshotIfNeeded() {
        guard settings.iCloudSyncEnabled else { return }
        guard let remoteData = CloudSyncService.shared.loadRemoteSnapshotData() else { return }
        guard let remoteSnapshot = try? decoder.decode(StudioStoreSnapshot.self, from: remoteData.data) else { return }

        let migratedRemoteSnapshot = Self.migrate(snapshot: remoteSnapshot)
        guard migratedRemoteSnapshot.lastModifiedAt > lastModifiedAt else { return }

        clients = migratedRemoteSnapshot.clients
        documents = migratedRemoteSnapshot.documents
        attachments = migratedRemoteSnapshot.attachments.filter { attachment in
            attachment.isExternalLink || attachmentFileExists(forRelativePath: attachment.localRelativePath)
        }
        if attachments.count != migratedRemoteSnapshot.attachments.count {
            lastSyncIssueMessage = "检测到来自 iCloud 的部分本地附件仅存在于原设备，当前设备会隐藏失效文件条目；如需完整迁移，请使用“完整备份（含附件）”。"
        }
        calendarLinks = migratedRemoteSnapshot.calendarLinks
        bookings = migratedRemoteSnapshot.bookings
        touchpoints = migratedRemoteSnapshot.touchpoints
        payments = migratedRemoteSnapshot.payments
        crewMembers = migratedRemoteSnapshot.crewMembers
        workspaceMembers = migratedRemoteSnapshot.workspaceMembers
        collaborationSettings = migratedRemoteSnapshot.collaborationSettings
        collaborationActivities = migratedRemoteSnapshot.collaborationActivities
        googleCalendarConnection = migratedRemoteSnapshot.googleCalendarConnection
        studioProfile = migratedRemoteSnapshot.studioProfile
        templates = migratedRemoteSnapshot.templates.isEmpty ? Self.defaultTemplates() : migratedRemoteSnapshot.templates
        authProfile = migratedRemoteSnapshot.authProfile ?? authProfile
        workspaceOwnerAppleUserID = migratedRemoteSnapshot.workspaceOwnerAppleUserID ?? workspaceOwnerAppleUserID
        lastModifiedAt = migratedRemoteSnapshot.lastModifiedAt

        var mergedSettings = migratedRemoteSnapshot.settings
        mergedSettings.iCloudSyncEnabled = true
        settings = mergedSettings
        AppFormatters.setCurrencyCode(mergedSettings.currencyCode)
        normalizeAndPersistIfNeeded(markModified: false)
    }

    private func registerCloudSyncObserver() {
        cloudSyncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adoptRemoteSnapshotIfNeeded()
            }
        }
    }

    private func suggestedLeadStage(for relatedBookings: [BookingRecord]) -> LeadStage {
        if relatedBookings.filter({ $0.status == .delivered }).count >= 2 {
            return .retained
        }
        if relatedBookings.contains(where: { [.confirmed, .shooting, .editing, .delivered].contains($0.status) }) {
            return .booked
        }
        if relatedBookings.contains(where: { [.tentative, .inquiry].contains($0.status) }) {
            return .negotiating
        }
        return .discovery
    }

    private func refreshSummaryNotifications() {
        guard settings.notificationsEnabled else {
            AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.followUpSummaryIdentifier)
            AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.outstandingSummaryIdentifier)
            return
        }

        let pendingFollowUps = touchpoints.filter {
            $0.isArchived == false && $0.isComplete == false
        }
        if settings.remindFollowUps, pendingFollowUps.isEmpty == false {
            AppNotificationManager.shared.scheduleFollowUpSummaryReminder(settings: settings, pendingCount: pendingFollowUps.count)
        } else {
            AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.followUpSummaryIdentifier)
        }

        let outstandingBookings = activeBookings.filter {
            $0.status != .cancelled && outstandingAmount(for: $0) > 0
        }
        if settings.remindOutstandingPayments, outstandingBookings.isEmpty == false {
            let totalOutstanding = outstandingBookings.reduce(0) { $0 + outstandingAmount(for: $1) }
            AppNotificationManager.shared.scheduleOutstandingSummaryReminder(
                settings: settings,
                bookingCount: outstandingBookings.count,
                totalOutstanding: totalOutstanding
            )
        } else {
            AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.outstandingSummaryIdentifier)
        }
    }

    private func startIsolatedWorkspace(for authProfile: AuthProfile) {
        var isolatedSettings = settings
        isolatedSettings.iCloudSyncEnabled = false
        isolatedSettings.crewLensEnabled = false
        isolatedSettings.currentCrewMemberID = nil
        isolatedSettings.currentMemberName = ""
        isolatedSettings.studioName = ""
        isolatedSettings.contactPhone = ""

        let snapshot = StudioStoreSnapshot(
            clients: [],
            documents: [],
            attachments: [],
            calendarLinks: [],
            workspaceMembers: [WorkspaceMemberRecord(appleUserID: authProfile.appleUserID, displayName: authProfile.fullName ?? authProfile.email ?? "工作区所有者", email: authProfile.email ?? "", role: .owner, status: .owner, notesText: "系统自动创建的工作区所有者。", createdAt: .now, lastSeenAt: .now, isActive: true)],
            collaborationSettings: .default,
            collaborationActivities: [],
            googleCalendarConnection: .empty,
            bookings: [],
            touchpoints: [],
            payments: [],
            crewMembers: [],
            studioProfile: .empty,
            templates: Self.defaultTemplates(),
            settings: isolatedSettings,
            authProfile: authProfile,
            workspaceOwnerAppleUserID: authProfile.appleUserID,
            lastModifiedAt: .now
        )
        apply(snapshot: snapshot)
    }

    private func removeOrphanedTouchpoints() {
        touchpoints.removeAll { $0.clientID == nil && $0.bookingID == nil }
    }

    private func refreshNotificationScheduling() {
        if settings.notificationsEnabled == false {
            AppNotificationManager.shared.removeAllManagedReminders(
                bookings: bookings,
                touchpoints: touchpoints
            )
            return
        }

        for booking in bookings where booking.isArchived == false {
            scheduleBookingReminderIfEnabled(for: booking)
        }
        for touchpoint in touchpoints where touchpoint.isArchived == false {
            scheduleTouchpointReminderIfEnabled(for: touchpoint)
        }
        refreshSummaryNotifications()
    }

    private func scheduleBookingReminderIfEnabled(for booking: BookingRecord) {
        guard settings.notificationsEnabled else { return }
        guard booking.isArchived == false else {
            AppNotificationManager.shared.removeBookingReminders(for: booking.id)
            return
        }
        AppNotificationManager.shared.scheduleBookingReminder(for: booking, settings: settings)
    }

    private func scheduleTouchpointReminderIfEnabled(for touchpoint: TouchpointRecord) {
        guard settings.notificationsEnabled else { return }
        guard touchpoint.isSystemReminderEnabled else {
            AppNotificationManager.shared.removeReminder(identifier: AppNotificationManager.touchpointIdentifier(for: touchpoint.id))
            return
        }
        AppNotificationManager.shared.scheduleTouchpointReminder(for: touchpoint, settings: settings)
    }

    func normalizeAndPersistIfNeeded(markModified: Bool = true) {
        clients.sort { $0.createdAt > $1.createdAt }
        documents.sort { $0.updatedAt > $1.updatedAt }
        attachments.sort { $0.updatedAt > $1.updatedAt }
        calendarLinks.sort { $0.updatedAt > $1.updatedAt }
        bookings.sort { $0.startAt < $1.startAt }
        touchpoints.sort { $0.dueAt < $1.dueAt }
        payments.sort { $0.date > $1.date }
        crewMembers.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        workspaceMembers.sort { $0.createdAt < $1.createdAt }
        collaborationActivities.sort { $0.createdAt > $1.createdAt }
        reconcileWorkspaceMembershipIfNeeded()
        rebuildPaymentCaches()
        rebuildRelationshipCaches()

        if settings.iCloudSyncEnabled && CloudSyncService.shared.isAvailable == false {
            settings.iCloudSyncEnabled = false
            lastSyncIssueMessage = "当前设备未检测到可用的 iCloud 账户，请先确认系统 iCloud 状态后再开启同步。"
        } else if settings.iCloudSyncEnabled && canEnableICloudSync == false {
            settings.iCloudSyncEnabled = false
            lastSyncIssueMessage = "当前工作区数据量已接近 iCloud 轻量同步上限，请先归档或导出历史数据后再开启同步。"
        } else if canEnableICloudSync {
            lastSyncIssueMessage = nil
        }

        if markModified {
            lastModifiedAt = .now
        }

        let visibleClients = activeClients
        let visibleBookings = activeBookings
        let visibleTouchpoints = touchpoints.filter { $0.isArchived == false }

        overviewSnapshot = OverviewSnapshotBuilder(now: .now).build(
            clients: visibleClients,
            bookings: visibleBookings,
            touchpoints: visibleTouchpoints,
            payments: payments
        )
        analyticsDashboardCache = buildAnalyticsDashboard()
        BookingReminderActivityManager.shared.sync(
            bookings: visibleBookings,
            clients: visibleClients,
            themeStyle: settings.themeStyle
        )
        refreshSummaryNotifications()
        schedulePersistence()
    }

    private func schedulePersistence() {
        pendingPersistenceTask?.cancel()

        let snapshot = currentSnapshot()
        let saveURL = self.saveURL
        let shouldPushToCloud = settings.iCloudSyncEnabled

        pendingPersistenceTask = Task(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }
            let outcome = await Task.detached(priority: .utility) {
                Self.persist(snapshot: snapshot, to: saveURL, pushToCloud: shouldPushToCloud)
            }.value
            guard Task.isCancelled == false else { return }
            applyPersistenceOutcome(outcome)
        }
    }

    private struct PersistenceOutcome: Sendable {
        var localWriteIssueMessage: String?
        var cloudPushIssueMessage: String?

        var hasIssue: Bool {
            localWriteIssueMessage != nil || cloudPushIssueMessage != nil
        }
    }

    private func applyPersistenceOutcome(_ outcome: PersistenceOutcome) {
        let issues = [outcome.localWriteIssueMessage, outcome.cloudPushIssueMessage]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if issues.isEmpty {
            lastPersistenceIssueMessage = nil
            lastPersistenceIssueAt = nil
            return
        }

        lastPersistenceIssueMessage = issues.joined(separator: "\n")
        lastPersistenceIssueAt = .now
        if let cloudPushIssueMessage = outcome.cloudPushIssueMessage {
            lastSyncIssueMessage = cloudPushIssueMessage
        }
    }

    private static func normalizedCrewMemberKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func persist(snapshot: StudioStoreSnapshot, to saveURL: URL, pushToCloud: Bool) -> PersistenceOutcome {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            let directory = saveURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: saveURL, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: saveURL.path
            )
            #endif

            var outcome = PersistenceOutcome()
            guard pushToCloud else { return outcome }
            do {
                try CloudSyncService.shared.push(snapshotData: data, lastModifiedAt: snapshot.lastModifiedAt)
            } catch {
                outcome.cloudPushIssueMessage = "iCloud 同步未完成：\(error.localizedDescription)"
            }
            return outcome
        } catch {
            return PersistenceOutcome(localWriteIssueMessage: "本地保存失败：\(error.localizedDescription)", cloudPushIssueMessage: nil)
        }
    }

    private func currentSnapshot() -> StudioStoreSnapshot {
        StudioStoreSnapshot(
            clients: clients,
            documents: documents,
            attachments: attachments,
            calendarLinks: calendarLinks,
            workspaceMembers: workspaceMembers,
            collaborationSettings: collaborationSettings,
            collaborationActivities: collaborationActivities,
            googleCalendarConnection: googleCalendarConnection.redactedForPersistence,
            bookings: bookings,
            touchpoints: touchpoints,
            payments: payments,
            crewMembers: crewMembers,
            studioProfile: studioProfile,
            templates: templates,
            settings: settings,
            authProfile: authProfile,
            workspaceOwnerAppleUserID: workspaceOwnerAppleUserID,
            lastModifiedAt: lastModifiedAt
        )
    }

    private static func loadSnapshot(at saveURL: URL, decoder: JSONDecoder, fileManager: FileManager) -> StudioStoreSnapshot {
        guard let data = try? Data(contentsOf: saveURL) else {
            return .empty
        }

        guard let snapshot = try? decoder.decode(StudioStoreSnapshot.self, from: data) else {
            backupCorruptedSnapshot(at: saveURL, fileManager: fileManager)
            return .empty
        }

        return snapshot
    }

    private func apply(snapshot: StudioStoreSnapshot, markModified: Bool = true) {
        pendingPersistenceTask?.cancel()
        clients = snapshot.clients
        documents = snapshot.documents
        attachments = snapshot.attachments
        calendarLinks = snapshot.calendarLinks
        bookings = snapshot.bookings
        touchpoints = snapshot.touchpoints
        payments = snapshot.payments
        crewMembers = snapshot.crewMembers
        workspaceMembers = snapshot.workspaceMembers
        collaborationSettings = snapshot.collaborationSettings
        collaborationActivities = snapshot.collaborationActivities
        googleCalendarConnection = snapshot.googleCalendarConnection.redactedForPersistence
        studioProfile = snapshot.studioProfile
        templates = snapshot.templates.isEmpty ? Self.defaultTemplates() : snapshot.templates
        settings = snapshot.settings
        authProfile = snapshot.authProfile
        workspaceOwnerAppleUserID = snapshot.workspaceOwnerAppleUserID
        lastModifiedAt = snapshot.lastModifiedAt
        AppFormatters.setCurrencyCode(snapshot.settings.currencyCode)
        reconcileWorkspaceMembershipIfNeeded()
        normalizeAndPersistIfNeeded(markModified: markModified)
    }

    private static func migrate(snapshot: StudioStoreSnapshot) -> StudioStoreSnapshot {
        var migrated = snapshot

        if migrated.crewMembers.isEmpty {
            migrated.crewMembers = []
        }
        if migrated.documents.isEmpty {
            migrated.documents = []
        }
        if migrated.attachments.isEmpty {
            migrated.attachments = []
        }
        if migrated.calendarLinks.isEmpty {
            migrated.calendarLinks = []
        }
        if migrated.workspaceMembers.isEmpty {
            migrated.workspaceMembers = []
        }
        if migrated.collaborationActivities.isEmpty {
            migrated.collaborationActivities = []
        }

        if migrated.studioProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           migrated.settings.studioName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            migrated.studioProfile.displayName = migrated.settings.studioName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if migrated.studioProfile.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           migrated.settings.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            migrated.studioProfile.contactPhone = AppFormatters.sanitizedPhoneNumber(migrated.settings.contactPhone)
        }
        if migrated.settings.studioName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            migrated.settings.studioName = migrated.studioProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if migrated.settings.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            migrated.settings.contactPhone = AppFormatters.sanitizedPhoneNumber(migrated.studioProfile.contactPhone)
        }
        migrated.settings.currencyCode = AppSettings.normalizedCurrencyCode(migrated.settings.currencyCode)

        if migrated.templates.isEmpty {
            migrated.templates = defaultTemplates()
        }

        if migrated.payments.isEmpty {
            migrated.payments = migrated.bookings.compactMap { booking in
                guard booking.depositPaid > 0 else { return nil }
                return PaymentRecord(
                    bookingID: booking.id,
                    amount: booking.depositPaid,
                    paymentType: .deposit,
                    date: min(booking.startAt, booking.createdAt),
                    note: systemManagedDepositNote
                )
            }
        }

        migrated.touchpoints = migrated.touchpoints.map { touchpoint in
            var draft = touchpoint
            if draft.source == .systemPreShootConfirmation {
                draft.isSystemReminderEnabled = true
            }
            return draft
        }

        migrated.bookings = migrated.bookings.map { booking in
            var draft = booking
            let total = migrated.payments
                .filter { $0.bookingID == booking.id }
                .reduce(0) { partialResult, payment in
                    let delta = payment.paymentType == .refund ? -payment.amount : payment.amount
                    return partialResult + delta
                }
            draft.depositPaid = max(total, 0)
            return draft
        }

        if migrated.workspaceOwnerAppleUserID == nil {
            migrated.workspaceOwnerAppleUserID = migrated.authProfile?.appleUserID
        }

        if migrated.workspaceMembers.isEmpty, let authProfile = migrated.authProfile {
            migrated.workspaceMembers = [
                WorkspaceMemberRecord(
                    appleUserID: authProfile.appleUserID,
                    displayName: authProfile.fullName ?? authProfile.email ?? "工作区所有者",
                    email: authProfile.email ?? "",
                    role: .owner,
                    status: .owner,
                    notesText: "由迁移逻辑自动补齐的所有者账号。",
                    createdAt: authProfile.signedInAt,
                    lastSeenAt: .now,
                    isActive: true
                )
            ]
        }

        let validBookingIDs = Set(migrated.bookings.map(\.id))
        migrated.calendarLinks = migrated.calendarLinks.filter { validBookingIDs.contains($0.bookingID) }
        migrated.documents = migrated.documents.map { document in
            var draft = document
            draft.updatedAt = max(draft.updatedAt, draft.createdAt)
            return draft
        }
        migrated.attachments = migrated.attachments.map { attachment in
            var draft = attachment
            draft.updatedAt = max(draft.updatedAt, draft.createdAt)
            return draft
        }
        if migrated.googleCalendarConnection.calendarID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            migrated.googleCalendarConnection.calendarID = "primary"
        }

        migrated.version = StudioStoreSnapshot.currentVersion
        return migrated
    }

    private static func backupCorruptedSnapshot(at saveURL: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: saveURL.path) else { return }

        let corruptURL = saveURL.deletingLastPathComponent()
            .appending(path: "studio-store-corrupted-\(Int(Date.now.timeIntervalSince1970)).json")

        try? fileManager.removeItem(at: corruptURL)
        try? fileManager.moveItem(at: saveURL, to: corruptURL)
    }

    private static func defaultTemplates() -> [BookingTemplate] {
        [
            BookingTemplate(
                name: "婚礼",
                category: .wedding,
                defaultDurationHours: 10,
                defaultPrice: 16800,
                defaultDepositRatio: 0.3,
                defaultReminderDays: 3,
                defaultDeliverableText: "精修照片 + 婚礼预告片",
                defaultNotesText: "确认时间线、联系人、机位和出行安排。"
            ),
            BookingTemplate(
                name: "个人写真",
                category: .portrait,
                defaultDurationHours: 3,
                defaultPrice: 3200,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 1,
                defaultDeliverableText: "精修 12 张 + 底片",
                defaultNotesText: "提前确认妆造、服装和场地风格。"
            ),
            BookingTemplate(
                name: "情侣写真",
                category: .couple,
                defaultDurationHours: 2,
                defaultPrice: 2999,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 1,
                defaultDeliverableText: "精修 18 张 + 双人合辑",
                defaultNotesText: "确认服装色系、情绪参考图和拍摄节奏。"
            ),
            BookingTemplate(
                name: "旅拍",
                category: .travel,
                defaultDurationHours: 5,
                defaultPrice: 6999,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 3,
                defaultDeliverableText: "精修 36 张 + 行程花絮",
                defaultNotesText: "确认路线、集合时间、交通和天气备选方案。"
            ),
            BookingTemplate(
                name: "企业形象照",
                category: .corporate,
                defaultDurationHours: 4,
                defaultPrice: 5200,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 3,
                defaultDeliverableText: "团队形象照 + 单人头像",
                defaultNotesText: "确认人数、服装规范、拍摄背景和选片规则。"
            ),
            BookingTemplate(
                name: "产品拍摄",
                category: .product,
                defaultDurationHours: 4,
                defaultPrice: 4200,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 3,
                defaultDeliverableText: "主图 + 细节图 + 横竖版素材",
                defaultNotesText: "确认拍摄清单、背景、道具和出图尺寸。"
            ),
            BookingTemplate(
                name: "美食拍摄",
                category: .food,
                defaultDurationHours: 4,
                defaultPrice: 4600,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 3,
                defaultDeliverableText: "菜单主图 + 场景图 + 竖版素材",
                defaultNotesText: "确认出餐节奏、餐具道具、菜品数量与上菜顺序。"
            ),
            BookingTemplate(
                name: "空间摄影",
                category: .space,
                defaultDurationHours: 3,
                defaultPrice: 3800,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 3,
                defaultDeliverableText: "空间全景 + 细节图 + 宣传横图",
                defaultNotesText: "确认采光时段、清场情况、重点区域和使用用途。"
            ),
            BookingTemplate(
                name: "活动跟拍",
                category: .event,
                defaultDurationHours: 5,
                defaultPrice: 4800,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 1,
                defaultDeliverableText: "活动纪实照片 + 关键环节快修",
                defaultNotesText: "确认流程表、嘉宾名单、主舞台和关键镜头。"
            ),
            BookingTemplate(
                name: "纪录片摄像",
                category: .documentaryFilm,
                defaultDurationHours: 8,
                defaultPrice: 8800,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 3,
                defaultDeliverableText: "纪录短片 + 采访素材 + 精简字幕版",
                defaultNotesText: "确认采访对象、拍摄提纲、授权范围和素材归档方式。"
            ),
            BookingTemplate(
                name: "航拍",
                category: .aerial,
                defaultDurationHours: 2,
                defaultPrice: 2600,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 1,
                defaultDeliverableText: "航拍照片 + 4K 航拍视频片段",
                defaultNotesText: "确认空域、报备要求、天气风速和起降点。"
            ),
            BookingTemplate(
                name: "视频拍摄",
                category: .video,
                defaultDurationHours: 6,
                defaultPrice: 7600,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 3,
                defaultDeliverableText: "横版主片 + 竖版短视频素材",
                defaultNotesText: "确认脚本、分镜、收音、灯光和交付比例。"
            ),
            BookingTemplate(
                name: "亲子全家福",
                category: .family,
                defaultDurationHours: 2,
                defaultPrice: 2600,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 1,
                defaultDeliverableText: "精修 24 张",
                defaultNotesText: "确认儿童作息、天气与备用场地。"
            ),
            BookingTemplate(
                name: "孕妇写真",
                category: .maternity,
                defaultDurationHours: 2,
                defaultPrice: 3600,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 2,
                defaultDeliverableText: "精修 20 张 + 海报 1 张",
                defaultNotesText: "确认孕周、服装、陪拍家属与体力安排。"
            ),
            BookingTemplate(
                name: "新生儿拍摄",
                category: .newborn,
                defaultDurationHours: 3,
                defaultPrice: 4200,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 2,
                defaultDeliverableText: "精修 20 张 + 亲子合照",
                defaultNotesText: "确认宝宝作息、保暖、喂奶时间和拍摄道具。"
            ),
            BookingTemplate(
                name: "宠物写真",
                category: .pet,
                defaultDurationHours: 2,
                defaultPrice: 1999,
                defaultDepositRatio: 0.5,
                defaultReminderDays: 1,
                defaultDeliverableText: "精修 15 张 + 连拍底片精选",
                defaultNotesText: "确认宠物状态、零食玩具、牵引要求和清洁安排。"
            ),
            BookingTemplate(
                name: "毕业照",
                category: .graduation,
                defaultDurationHours: 2,
                defaultPrice: 2200,
                defaultDepositRatio: 0.4,
                defaultReminderDays: 1,
                defaultDeliverableText: "精修 18 张 + 合影底片",
                defaultNotesText: "确认学位服、场地、同伴人数与天气方案。"
            )
        ]
    }
}

enum BusinessModuleError: LocalizedError {
    case permissionDenied(String)
    case attachmentImportFailed(String)
    case calendarSyncUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .permissionDenied(message),
             let .attachmentImportFailed(message),
             let .calendarSyncUnavailable(message):
            return message
        }
    }
}

extension StudioStore {
    struct BusinessSummary: Hashable, Sendable {
        var documents: Int
        var attachments: Int
    }

    var activeDocuments: [BusinessDocumentRecord] {
        documents.filter { $0.isArchived == false }
    }

    var activeAttachments: [AttachmentRecord] {
        attachments.filter { $0.isArchived == false }
    }

    var activeWorkspaceMembers: [WorkspaceMemberRecord] {
        workspaceMembers.filter { $0.isActive && $0.status != .suspended }
    }

    var currentWorkspaceRole: WorkspaceRole {
        if workspaceMembers.isEmpty {
            return .owner
        }

        guard let authProfile else {
            return .viewer
        }

        if let matchedMember = workspaceMembers.first(where: { member in
            member.appleUserID == authProfile.appleUserID ||
            (member.email.isEmpty == false &&
             member.email.caseInsensitiveCompare(authProfile.email ?? "") == .orderedSame)
        }) {
            return matchedMember.role
        }

        if workspaceOwnerAppleUserID == authProfile.appleUserID {
            return .owner
        }

        return .viewer
    }

    var analyticsDashboard: BusinessAnalyticsDashboard {
        analyticsDashboardCache
    }

    private func buildAnalyticsDashboard() -> BusinessAnalyticsDashboard {
        let scopedBookings = activeBookings.filter { $0.status != .cancelled }
        guard scopedBookings.isEmpty == false else { return .empty }

        let totalBookedAmount = scopedBookings.reduce(0) { $0 + $1.fee }
        let totalCollectedAmount = scopedBookings.reduce(0) { partialResult, booking in
            partialResult + receivedAmount(for: booking)
        }
        let totalOutstandingAmount = scopedBookings.reduce(0) { partialResult, booking in
            partialResult + outstandingAmount(for: booking)
        }
        let averageTicketAmount = totalBookedAmount / Double(max(scopedBookings.count, 1))

        let visibleClients = activeClients
        let bookingCountsByClient = Dictionary(grouping: scopedBookings.compactMap(\.clientID), by: { $0 })
            .mapValues(\.count)
        let repeatClientCount = bookingCountsByClient.values.filter { $0 >= 2 }.count
        let repeatClientRate = visibleClients.isEmpty ? 0 : Double(repeatClientCount) / Double(visibleClients.count)
        let retentionClientCount = visibleClients.filter { $0.stage == .retained }.count

        let calendar = Calendar(identifier: .gregorian)
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let revenueTrend = (0..<6).compactMap { offset -> BusinessAnalyticsRevenuePoint? in
            guard let monthStart = calendar.date(byAdding: .month, value: offset - 5, to: currentMonth) else {
                return nil
            }

            let bookedAmount = scopedBookings
                .filter { calendar.isDate($0.startAt, equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { $0 + $1.fee }
            let collectedAmount = payments
                .filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { partialResult, payment in
                    let delta = payment.paymentType == .refund ? -payment.amount : payment.amount
                    return partialResult + delta
                }

            return BusinessAnalyticsRevenuePoint(
                monthStart: monthStart,
                bookedAmount: max(bookedAmount, 0),
                collectedAmount: max(collectedAmount, 0)
            )
        }

        let categoryBreakdown = Dictionary(grouping: scopedBookings, by: \.category)
            .map { category, bookings in
                BusinessAnalyticsCategoryPoint(
                    category: category,
                    bookingCount: bookings.count,
                    bookedAmount: bookings.reduce(0) { $0 + $1.fee }
                )
            }
            .sorted { $0.bookedAmount > $1.bookedAmount }

        let sourceBreakdown = Dictionary(grouping: visibleClients, by: { client in
            let normalized = client.sourceChannel.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "未标记来源" : normalized
        })
            .map { source, clients in
                let clientIDs = Set(clients.map(\.id))
                let bookedAmount = scopedBookings
                    .filter { booking in
                        guard let clientID = booking.clientID else { return false }
                        return clientIDs.contains(clientID)
                    }
                    .reduce(0) { $0 + $1.fee }
                return BusinessAnalyticsSourcePoint(
                    sourceChannel: source,
                    clientCount: clients.count,
                    bookedAmount: bookedAmount
                )
            }
            .sorted { $0.bookedAmount > $1.bookedAmount }

        let overdueBookings = scopedBookings.filter { outstandingAmount(for: $0) > 0 }
        let agingBuckets = makeAgingBuckets(from: overdueBookings, calendar: calendar)

        return BusinessAnalyticsDashboard(
            totalBookedAmount: totalBookedAmount,
            totalCollectedAmount: totalCollectedAmount,
            totalOutstandingAmount: totalOutstandingAmount,
            averageTicketAmount: averageTicketAmount,
            repeatClientRate: repeatClientRate,
            retentionClientCount: retentionClientCount,
            revenueTrend: revenueTrend,
            categoryBreakdown: categoryBreakdown,
            sourceBreakdown: sourceBreakdown,
            agingBuckets: agingBuckets
        )
    }

    func canCurrentUserPerform(_ permission: WorkspacePermission) -> Bool {
        if workspaceMembers.isEmpty {
            return true
        }

        if permission == .exportData && currentWorkspaceRole == .viewer {
            return collaborationSettings.allowViewerExport
        }

        if permission == .manageAttachments && currentWorkspaceRole == .photographer {
            return collaborationSettings.allowAttachmentUploadByPhotographers && currentWorkspaceRole.permissions.contains(permission)
        }

        return currentWorkspaceRole.permissions.contains(permission)
    }

    func documents(for bookingID: UUID?, clientID: UUID?) -> [BusinessDocumentRecord] {
        let scopedBookingIDs = relatedBookingIDs(for: bookingID, clientID: clientID)
        return activeDocuments
            .filter { matchesScope(recordBookingID: $0.bookingID, recordClientID: $0.clientID, scopedBookingIDs: scopedBookingIDs, clientID: clientID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func attachments(for bookingID: UUID?, clientID: UUID?) -> [AttachmentRecord] {
        let scopedBookingIDs = relatedBookingIDs(for: bookingID, clientID: clientID)
        return activeAttachments
            .filter { matchesScope(recordBookingID: $0.bookingID, recordClientID: $0.clientID, scopedBookingIDs: scopedBookingIDs, clientID: clientID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func businessSummary(for bookingID: UUID?, clientID: UUID?) -> BusinessSummary {
        BusinessSummary(
            documents: documents(for: bookingID, clientID: clientID).count,
            attachments: attachments(for: bookingID, clientID: clientID).count
        )
    }

    func calendarLink(for bookingID: UUID, provider: CalendarSyncProvider) -> CalendarSyncLinkRecord? {
        calendarLinks.first { $0.bookingID == bookingID && $0.provider == provider }
    }

    func makeSuggestedDocument(kind: BusinessDocumentKind, bookingID: UUID?, clientID: UUID?) -> BusinessDocumentRecord {
        let relatedBooking = bookingID.flatMap { booking(id: $0) }
        let resolvedClientID = clientID ?? relatedBooking?.clientID
        let relatedClient = resolvedClientID.flatMap { client(id: $0) }
        let recipientName = relatedClient?.name ?? "未命名客户"
        let title = [recipientName, kind.title].joined(separator: " · ")
        let issueDate = Date.now
        let sequence = documents.filter { $0.kind == kind }.count + 1
        let number = "\(kind.prefix)-\(String(format: "%04d", sequence))"

        let lineItems: [BusinessDocumentLineItem]
        if let relatedBooking {
            let suggestedAmount: Double
            let suggestedDetails: String
            switch kind {
            case .quote, .contract:
                suggestedAmount = relatedBooking.fee
                suggestedDetails = relatedBooking.deliverableText
            case .receipt:
                let received = receivedAmount(for: relatedBooking)
                suggestedAmount = received > 0 ? received : relatedBooking.depositPaid
                suggestedDetails = "已收款项记录，用于客户回执与内部对账。"
            case .invoice:
                let outstanding = outstandingAmount(for: relatedBooking)
                suggestedAmount = outstanding > 0 ? outstanding : relatedBooking.fee
                suggestedDetails = outstanding > 0 ? "当前订单待开票 / 待收余额。" : relatedBooking.deliverableText
            }
            lineItems = [
                BusinessDocumentLineItem(
                    title: relatedBooking.title,
                    detailsText: suggestedDetails,
                    quantity: 1,
                    unitPrice: suggestedAmount
                )
            ]
        } else {
            lineItems = [BusinessDocumentLineItem(title: kind.title, unitPrice: 0)]
        }

        return BusinessDocumentRecord(
            bookingID: bookingID,
            clientID: resolvedClientID,
            kind: kind,
            status: .draft,
            number: number,
            title: title,
            recipientName: recipientName,
            issueDate: issueDate,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: issueDate),
            lineItems: lineItems,
            notesText: relatedBooking?.notesText ?? "",
            termsText: "默认条款可按实际合作内容调整。"
        )
    }

    func attachmentFileURL(for attachment: AttachmentRecord) -> URL? {
        guard let relativePath = attachment.localRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines),
              relativePath.isEmpty == false else {
            return nil
        }
        let resolvedURL = saveURL.deletingLastPathComponent().appending(path: relativePath)
        guard fileManager.fileExists(atPath: resolvedURL.path) else {
            return nil
        }
        return resolvedURL
    }

    func attachmentAvailabilityMessage(for attachment: AttachmentRecord) -> String? {
        guard attachment.isLocalFile else { return nil }
        return attachmentFileURL(for: attachment) == nil
            ? "该文件没有随 iCloud 轻量同步一起迁移，当前设备仅保留附件记录。请在原设备导出“完整备份（含附件）”后再恢复。"
            : nil
    }

    func importAttachment(
        from sourceURL: URL,
        bookingID: UUID?,
        clientID: UUID?,
        category: AttachmentCategory,
        title: String
    ) throws -> AttachmentRecord {
        guard requirePermission(.manageAttachments) else {
            throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有上传附件权限。")
        }

        let attachmentsDirectory = attachmentsDirectoryURL
        try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        let sanitizedName = sanitizedFileName(title.isEmpty ? sourceURL.lastPathComponent : title)
        let fileExtension = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetFileName = fileExtension.isEmpty
            ? "\(UUID().uuidString)-\(sanitizedName)"
            : "\(UUID().uuidString)-\(sanitizedName).\(fileExtension)"
        let targetURL = attachmentsDirectory.appending(path: targetFileName)

        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            #if os(iOS)
            try? fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: targetURL.path)
            #endif
        } catch {
            throw BusinessModuleError.attachmentImportFailed("导入附件失败：\(error.localizedDescription)")
        }

        let byteCount = Int64((try? targetURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let relativePath = "Attachments/\(targetFileName)"
        let attachment = AttachmentRecord(
            bookingID: bookingID,
            clientID: clientID,
            category: category,
            title: title.isEmpty ? sourceURL.deletingPathExtension().lastPathComponent : title,
            localRelativePath: relativePath,
            mimeType: inferredMimeType(for: sourceURL),
            byteCount: byteCount
        )

        upsert(attachment: attachment)
        return attachment
    }

    func markDocumentShared(_ documentID: UUID) {
        guard requirePermission(.manageDocuments) else { return }
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[index].lastSharedAt = .now
        if documents[index].status == .draft {
            documents[index].status = .sent
        }
        documents[index].updatedAt = .now
        appendActivity(actionTitle: "分享文档", target: .document, targetID: documentID.uuidString, summary: documents[index].title)
        normalizeAndPersistIfNeeded()
    }

    func upsert(document: BusinessDocumentRecord) {
        guard requirePermission(.manageDocuments) else { return }
        let isExisting = documents.contains { $0.id == document.id }
        var normalized = document
        normalized.updatedAt = .now
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = normalized
        } else {
            documents.append(normalized)
        }
        appendActivity(actionTitle: isExisting ? "更新文档" : "新建文档", target: .document, targetID: normalized.id.uuidString, summary: normalized.title)
        normalizeAndPersistIfNeeded()
    }

    func upsert(attachment: AttachmentRecord) {
        guard requirePermission(.manageAttachments) else { return }
        let isExisting = attachments.contains { $0.id == attachment.id }
        var normalized = attachment
        normalized.updatedAt = .now
        if let index = attachments.firstIndex(where: { $0.id == attachment.id }) {
            attachments[index] = normalized
        } else {
            attachments.append(normalized)
        }
        appendActivity(actionTitle: isExisting ? "更新附件" : "新增附件", target: .attachment, targetID: normalized.id.uuidString, summary: normalized.title)
        normalizeAndPersistIfNeeded()
    }

    func upsert(workspaceMember: WorkspaceMemberRecord) {
        guard requirePermission(.manageWorkspace) else { return }
        let isExisting = workspaceMembers.contains { $0.id == workspaceMember.id }
        if let index = workspaceMembers.firstIndex(where: { $0.id == workspaceMember.id }) {
            workspaceMembers[index] = workspaceMember
        } else {
            workspaceMembers.append(workspaceMember)
        }
        appendActivity(actionTitle: isExisting ? "更新成员" : "新增成员", target: .workspace, targetID: workspaceMember.id.uuidString, summary: workspaceMember.displayName)
        normalizeAndPersistIfNeeded()
    }

    func updateCollaborationSettings(_ settings: WorkspaceCollaborationSettings) {
        guard requirePermission(.manageWorkspace) else { return }
        var normalized = settings
        normalized.realtimeSyncEnabled = false
        normalized.showPresenceBoard = false
        normalized.requireFinancialApproval = false
        collaborationSettings = normalized
        appendActivity(actionTitle: "更新协作设置", target: .workspace, targetID: "collaboration-settings", summary: "团队权限与导出策略已更新")
        normalizeAndPersistIfNeeded()
    }

    func updateGoogleCalendarConnection(_ connection: GoogleCalendarConnection) {
        guard requirePermission(.manageCalendarSync) else { return }
        googleCalendarConnection = connection.redactedForPersistence
        appendActivity(actionTitle: "更新日历接入信息", target: .calendarSync, targetID: "google-calendar", summary: connection.accountEmail.isEmpty ? "Google Calendar" : connection.accountEmail)
        normalizeAndPersistIfNeeded()
    }

    func pushBookingToSystemCalendar(_ bookingID: UUID) async throws {
        guard requirePermission(.manageCalendarSync) else {
            throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有日历同步权限。")
        }
        throw BusinessModuleError.calendarSyncUnavailable("当前正式版暂未启用系统日历写入，请先在经营中心查看接入说明。")
    }

    func pullSystemCalendarChanges(_ bookingID: UUID) async throws {
        guard requirePermission(.manageCalendarSync) else {
            throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有日历同步权限。")
        }
        throw BusinessModuleError.calendarSyncUnavailable("当前正式版暂未启用系统日历回写，请先在经营中心查看接入说明。")
    }

    func pushBookingToGoogleCalendar(_ bookingID: UUID) async throws {
        guard requirePermission(.manageCalendarSync) else {
            throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有日历同步权限。")
        }
        throw BusinessModuleError.calendarSyncUnavailable("当前正式版暂未启用 Google Calendar 写入，请先在经营中心查看接入说明。")
    }

    func pullGoogleCalendarChanges(_ bookingID: UUID) async throws {
        guard requirePermission(.manageCalendarSync) else {
            throw BusinessModuleError.permissionDenied(lastWorkspaceNoticeMessage ?? "没有日历同步权限。")
        }
        throw BusinessModuleError.calendarSyncUnavailable("当前正式版暂未启用 Google Calendar 回写，请先在经营中心查看接入说明。")
    }

    @discardableResult
    private func requirePermission(_ permission: WorkspacePermission) -> Bool {
        let allowed = canCurrentUserPerform(permission)
        if allowed == false {
            lastWorkspaceNoticeMessage = "当前账号缺少“\(permission.title)”权限。"
        } else {
            lastWorkspaceNoticeMessage = nil
        }
        return allowed
    }

    private func appendActivity(actionTitle: String, target: CollaborationActivityTarget, targetID: String, summary: String) {
        let actorMember = currentWorkspaceMember()
        let activity = CollaborationActivityRecord(
            actorMemberID: actorMember?.id,
            actorDisplayName: actorMember?.displayName ?? authProfile?.fullName ?? authProfile?.email ?? "当前设备",
            actionTitle: actionTitle,
            target: target,
            targetID: targetID,
            summary: summary
        )
        collaborationActivities.append(activity)
    }

    private func reconcileWorkspaceMembershipIfNeeded() {
        guard let authProfile else { return }
        let ownerName = authProfile.fullName ?? authProfile.email ?? "工作区所有者"

        if let ownerIndex = workspaceMembers.firstIndex(where: { $0.appleUserID == authProfile.appleUserID }) {
            workspaceMembers[ownerIndex].role = workspaceOwnerAppleUserID == authProfile.appleUserID ? .owner : workspaceMembers[ownerIndex].role
            workspaceMembers[ownerIndex].status = workspaceMembers[ownerIndex].role == .owner ? .owner : workspaceMembers[ownerIndex].status
            workspaceMembers[ownerIndex].displayName = workspaceMembers[ownerIndex].displayName.isEmpty ? ownerName : workspaceMembers[ownerIndex].displayName
            workspaceMembers[ownerIndex].lastSeenAt = .now
            workspaceMembers[ownerIndex].isActive = true
        } else if workspaceOwnerAppleUserID == authProfile.appleUserID || workspaceMembers.isEmpty {
            workspaceMembers.append(
                WorkspaceMemberRecord(
                    appleUserID: authProfile.appleUserID,
                    displayName: ownerName,
                    email: authProfile.email ?? "",
                    role: .owner,
                    status: .owner,
                    notesText: "系统自动维护的工作区所有者。",
                    createdAt: authProfile.signedInAt,
                    lastSeenAt: .now,
                    isActive: true
                )
            )
        }
    }

    private func currentWorkspaceMember() -> WorkspaceMemberRecord? {
        guard let authProfile else { return nil }
        return workspaceMembers.first(where: { member in
            member.appleUserID == authProfile.appleUserID ||
            (member.email.isEmpty == false &&
             member.email.caseInsensitiveCompare(authProfile.email ?? "") == .orderedSame)
        })
    }

    private func relatedBookingIDs(for bookingID: UUID?, clientID: UUID?) -> Set<UUID> {
        var ids: Set<UUID> = []
        if let bookingID {
            ids.insert(bookingID)
        }
        if let clientID {
            bookings(for: clientID, includeArchived: true).forEach { ids.insert($0.id) }
        }
        return ids
    }

    private func matchesScope(
        recordBookingID: UUID?,
        recordClientID: UUID?,
        scopedBookingIDs: Set<UUID>,
        clientID: UUID?
    ) -> Bool {
        if scopedBookingIDs.isEmpty == false, let recordBookingID, scopedBookingIDs.contains(recordBookingID) {
            return true
        }
        if let clientID, recordClientID == clientID {
            return true
        }
        if scopedBookingIDs.isEmpty && clientID == nil {
            return true
        }
        return false
    }

    private func makeAgingBuckets(from bookings: [BookingRecord], calendar: Calendar) -> [BusinessAnalyticsAgingBucket] {
        let bucketTitles = ["未到期", "0-7天", "8-30天", "31天+"]
        var totals = Dictionary(uniqueKeysWithValues: bucketTitles.map { ($0, (amount: 0.0, count: 0)) })

        for booking in bookings {
            let outstanding = outstandingAmount(for: booking)
            guard outstanding > 0 else { continue }

            let dayDelta = calendar.dateComponents([.day], from: booking.startAt, to: .now).day ?? 0
            let bucket: String
            if dayDelta < 0 {
                bucket = "未到期"
            } else if dayDelta <= 7 {
                bucket = "0-7天"
            } else if dayDelta <= 30 {
                bucket = "8-30天"
            } else {
                bucket = "31天+"
            }

            totals[bucket, default: (0, 0)].amount += outstanding
            totals[bucket, default: (0, 0)].count += 1
        }

        return bucketTitles.compactMap { title in
            guard let value = totals[title], value.count > 0 else { return nil }
            return BusinessAnalyticsAgingBucket(title: title, amount: value.amount, bookingCount: value.count)
        }
    }

    private var attachmentsDirectoryURL: URL {
        saveURL.deletingLastPathComponent().appending(path: "Attachments", directoryHint: .isDirectory)
    }

    private func inferredMimeType(for url: URL) -> String {
        #if canImport(UniformTypeIdentifiers)
        let fileExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if let type = UTType(filenameExtension: fileExtension), let mimeType = type.preferredMIMEType {
            return mimeType
        }
        #endif
        return "application/octet-stream"
    }

    private func paymentSummary(for bookingID: UUID) -> PaymentComputation {
        paymentSummaryByBookingID[bookingID] ?? .empty
    }

    private func rebuildPaymentCaches() {
        let grouped = Dictionary(grouping: payments, by: \.bookingID)
        paymentsByBookingID = grouped.mapValues { records in
            records.sorted { $0.date > $1.date }
        }
        paymentSummaryByBookingID = paymentsByBookingID.mapValues { records in
            let refunds = records.filter { $0.paymentType == .refund }.reduce(0) { $0 + max($1.amount, 0) }
            let positivePayments = records.filter { $0.paymentType != .refund }.reduce(0) { $0 + max($1.amount, 0) }
            return PaymentComputation(
                sortedRecords: records,
                refunds: refunds,
                positivePayments: positivePayments,
                received: max(positivePayments - refunds, 0),
                hasBalancePayment: records.contains { $0.paymentType == .balance && $0.amount > 0 }
            )
        }
    }

    private func rebuildRelationshipCaches() {
        let bookingsWithClientID = bookings.compactMap { booking -> (UUID, BookingRecord)? in
            guard let clientID = booking.clientID else { return nil }
            return (clientID, booking)
        }
        bookingsByClientID = Dictionary(grouping: bookingsWithClientID, by: \.0).mapValues { records in
            records.map(\.1).sorted { $0.startAt > $1.startAt }
        }

        let touchpointsWithClientID = touchpoints.compactMap { touchpoint -> (UUID, TouchpointRecord)? in
            guard let clientID = touchpoint.clientID else { return nil }
            return (clientID, touchpoint)
        }
        touchpointsByClientID = Dictionary(grouping: touchpointsWithClientID, by: \.0).mapValues { records in
            records.map(\.1).sorted { $0.dueAt < $1.dueAt }
        }
    }

    private func loadBackupPayload(from url: URL) throws -> (snapshotData: Data, attachmentsDirectoryURL: URL?) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values?.isDirectory ?? false

        if isDirectory {
            let manifestURL = url.appending(path: StoreExportService.backupManifestFileName)
            let data = try Data(contentsOf: manifestURL)
            let attachmentsURL = url.appending(path: StoreExportService.backupAttachmentsDirectoryName, directoryHint: .isDirectory)
            let existingAttachmentsURL = fileManager.fileExists(atPath: attachmentsURL.path) ? attachmentsURL : nil
            return (data, existingAttachmentsURL)
        }

        return (try Data(contentsOf: url), nil)
    }

    private func preparedRestoredAttachmentsDirectory(from backupAttachmentsDirectory: URL?) throws -> URL? {
        guard let backupAttachmentsDirectory else { return nil }

        let stagingDirectory = saveURL.deletingLastPathComponent().appending(path: "Attachments.restore_tmp", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: stagingDirectory.path) {
            try fileManager.removeItem(at: stagingDirectory)
        }
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        do {
            let files = try fileManager.contentsOfDirectory(at: backupAttachmentsDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let destination = stagingDirectory.appending(path: file.lastPathComponent, directoryHint: file.hasDirectoryPath ? .isDirectory : .notDirectory)
                try copyItemRecursivelyIfNeeded(from: file, to: destination)
            }
            return stagingDirectory
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    private func replaceAttachmentsDirectory(withPreparedContentsAt stagingDirectory: URL) throws {
        let backupDirectory = saveURL.deletingLastPathComponent().appending(path: "Attachments.previous", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.removeItem(at: backupDirectory)
        }

        do {
            if fileManager.fileExists(atPath: attachmentsDirectoryURL.path) {
                try fileManager.moveItem(at: attachmentsDirectoryURL, to: backupDirectory)
            }
            try fileManager.moveItem(at: stagingDirectory, to: attachmentsDirectoryURL)
            if fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.removeItem(at: backupDirectory)
            }
        } catch {
            if fileManager.fileExists(atPath: attachmentsDirectoryURL.path) == false,
               fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: attachmentsDirectoryURL)
            }
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    private func copyItemRecursivelyIfNeeded(from sourceURL: URL, to destinationURL: URL) throws {
        if sourceURL.hasDirectoryPath {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            let children = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
            for child in children {
                let childDestination = destinationURL.appending(path: child.lastPathComponent, directoryHint: child.hasDirectoryPath ? .isDirectory : .notDirectory)
                try copyItemRecursivelyIfNeeded(from: child, to: childDestination)
            }
            return
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func attachmentFileExists(forRelativePath relativePath: String?) -> Bool {
        guard let relativePath = relativePath?.trimmingCharacters(in: .whitespacesAndNewlines), relativePath.isEmpty == false else {
            return false
        }
        let fileURL = saveURL.deletingLastPathComponent().appending(path: relativePath)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    private func purgeAttachmentStorage() {
        guard fileManager.fileExists(atPath: attachmentsDirectoryURL.path) else { return }
        try? fileManager.removeItem(at: attachmentsDirectoryURL)
    }

    private func sanitizedFileName(_ value: String) -> String {
        let sanitized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return sanitized.isEmpty ? "attachment" : sanitized
    }

    private func updateCalendarLink(
        for bookingID: UUID,
        provider: CalendarSyncProvider,
        externalCalendarID: String,
        externalEventID: String,
        status: CalendarSyncStatus
    ) throws {
        guard let booking = booking(id: bookingID) else {
            throw BusinessModuleError.calendarSyncUnavailable("未找到对应订单，无法同步日历。")
        }

        let now = Date.now
        if let index = calendarLinks.firstIndex(where: { $0.bookingID == bookingID && $0.provider == provider }) {
            calendarLinks[index].externalCalendarID = externalCalendarID
            calendarLinks[index].externalEventID = externalEventID
            calendarLinks[index].direction = provider == .google ? googleCalendarConnection.syncDirection : .twoWay
            calendarLinks[index].status = status
            calendarLinks[index].lastSyncedAt = now
            calendarLinks[index].lastKnownExternalStartAt = booking.startAt
            calendarLinks[index].lastKnownExternalEndAt = booking.endAt
            calendarLinks[index].updatedAt = now
        } else {
            calendarLinks.append(
                CalendarSyncLinkRecord(
                    bookingID: bookingID,
                    provider: provider,
                    externalCalendarID: externalCalendarID,
                    externalEventID: externalEventID,
                    direction: provider == .google ? googleCalendarConnection.syncDirection : .twoWay,
                    status: status,
                    lastSyncedAt: now,
                    lastKnownExternalStartAt: booking.startAt,
                    lastKnownExternalEndAt: booking.endAt,
                    notesText: "本地占位同步记录"
                )
            )
        }

        appendActivity(actionTitle: "同步日历", target: .calendarSync, targetID: bookingID.uuidString, summary: "\(provider.title)：\(booking.title)")
        normalizeAndPersistIfNeeded()
    }
}

struct AppNotificationManager {
    static let shared = AppNotificationManager()
    static let followUpSummaryIdentifier = "summary-followup-reminder"
    static let outstandingSummaryIdentifier = "summary-outstanding-reminder"

    static func bookingIdentifier(for bookingID: UUID, offset: BookingReminderOffset) -> String {
        "booking-reminder-\(bookingID.uuidString)-\(offset.rawValue)"
    }

    static func bookingIdentifiers(for bookingID: UUID) -> [String] {
        BookingReminderOffset.allCases.map { bookingIdentifier(for: bookingID, offset: $0) }
    }

    static func touchpointIdentifier(for touchpointID: UUID) -> String {
        "touchpoint-reminder-\(touchpointID.uuidString)"
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let currentSettings = await center.notificationSettings()
        let currentStatus = currentSettings.authorizationStatus

        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        let refreshedSettings = await center.notificationSettings()
        return refreshedSettings.authorizationStatus
    }

    func requestAuthorization() {
        Task {
            _ = await requestAuthorizationIfNeeded()
        }
    }

    func scheduleBookingReminder(for booking: BookingRecord, settings: AppSettings) {
        guard settings.notificationsEnabled else { return }
        removeBookingReminders(for: booking.id)
        for offset in BookingReminderOffset.normalized(booking.reminderOffsets) {
            schedule(
                identifier: Self.bookingIdentifier(for: booking.id, offset: offset),
                title: reminderTitle(for: offset),
                body: "\(booking.title) · \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt)) · \(booking.venue)",
                fireDate: bookingReminderFireDate(for: booking, offset: offset, settings: settings)
            )
        }
    }

    func scheduleTouchpointReminder(for touchpoint: TouchpointRecord, settings: AppSettings) {
        guard settings.notificationsEnabled else { return }
        guard touchpoint.isArchived == false, touchpoint.isComplete == false, touchpoint.isSystemReminderEnabled else {
            removeReminder(identifier: Self.touchpointIdentifier(for: touchpoint.id))
            return
        }

        schedule(
            identifier: Self.touchpointIdentifier(for: touchpoint.id),
            title: "客户跟进提醒",
            body: touchpoint.title,
            fireDate: touchpointReminderFireDate(for: touchpoint, settings: settings)
        )
    }

    func scheduleFollowUpSummaryReminder(settings: AppSettings, pendingCount: Int) {
        guard settings.notificationsEnabled else { return }
        scheduleDailySummaryReminder(
            identifier: Self.followUpSummaryIdentifier,
            title: "今日跟进总提醒",
            body: "当前还有 \(pendingCount) 条待跟进事项，建议尽快处理。",
            hour: settings.defaultReminderHour
        )
    }

    func scheduleOutstandingSummaryReminder(settings: AppSettings, bookingCount: Int, totalOutstanding: Double) {
        guard settings.notificationsEnabled else { return }
        scheduleDailySummaryReminder(
            identifier: Self.outstandingSummaryIdentifier,
            title: "今日回款总提醒",
            body: "当前还有 \(bookingCount) 个项目待回款，共 \(AppFormatters.currency(totalOutstanding))。",
            hour: settings.defaultReminderHour
        )
    }

    func removeReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func removeBookingReminders(for bookingID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.bookingIdentifiers(for: bookingID)
        )
    }

    func removeAllManagedReminders(bookings: [BookingRecord], touchpoints: [TouchpointRecord]) {
        let identifiers = bookings.flatMap { Self.bookingIdentifiers(for: $0.id) }
            + touchpoints.map { Self.touchpointIdentifier(for: $0.id) }
            + [Self.followUpSummaryIdentifier, Self.outstandingSummaryIdentifier]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func bookingReminderFireDate(
        for booking: BookingRecord,
        offset: BookingReminderOffset,
        settings: AppSettings,
        calendar: Calendar = .current
    ) -> Date {
        switch offset {
        case .threeDaysBefore:
            return reminderDate(dayOffset: -3, booking: booking, settings: settings, calendar: calendar)
        case .oneDayBefore:
            return reminderDate(dayOffset: -1, booking: booking, settings: settings, calendar: calendar)
        case .sameDayMorning:
            let reminder = reminderDate(dayOffset: 0, booking: booking, settings: settings, calendar: calendar)
            return reminder < booking.startAt ? reminder : booking.startAt.addingTimeInterval(-3600)
        case .twoHoursBefore:
            return booking.startAt.addingTimeInterval(-7200)
        }
    }

    func touchpointReminderFireDate(for touchpoint: TouchpointRecord, settings: AppSettings, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: touchpoint.dueAt)
        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: settings.defaultReminderHour,
                minute: 0
            )
        ) ?? touchpoint.dueAt
    }

    func canScheduleNotification(fireDate: Date, now: Date = .now) -> Bool {
        fireDate > now.addingTimeInterval(90)
    }

    private func reminderDate(
        dayOffset: Int,
        booking: BookingRecord,
        settings: AppSettings,
        calendar: Calendar
    ) -> Date {
        let reminderDay = calendar.date(byAdding: .day, value: dayOffset, to: booking.startAt) ?? booking.startAt
        let components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: settings.defaultReminderHour,
                minute: 0
            )
        ) ?? reminderDay
    }

    private func reminderTitle(for offset: BookingReminderOffset) -> String {
        switch offset {
        case .threeDaysBefore: "3 天后有拍摄安排"
        case .oneDayBefore: "明天有拍摄安排"
        case .sameDayMorning: "今天有拍摄安排"
        case .twoHoursBefore: "距离拍摄还有 2 小时"
        }
    }

    private func scheduleDailySummaryReminder(identifier: String, title: String, body: String, hour: Int) {
        Task {
            let status = await requestAuthorizationIfNeeded()
            guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: 0),
                repeats: true
            )
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func schedule(identifier: String, title: String, body: String, fireDate: Date) {
        guard canScheduleNotification(fireDate: fireDate) else { return }

        Task {
            let status = await requestAuthorizationIfNeeded()
            guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
