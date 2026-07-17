import Foundation
import Testing

@testable import YingQi

struct ReleaseReadinessTests {
    @Test
    @MainActor
    func studioStoreStartsEmptyWithoutPersistedSnapshot() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)

        #expect(store.isWorkspaceEmpty)
        #expect(store.clients.isEmpty)
        #expect(store.bookings.isEmpty)
        #expect(store.touchpoints.isEmpty)
    }

    @Test
    @MainActor
    func sampleDataImportOnlyWorksForEmptyWorkspace() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)

        #expect(store.importSampleDataIfEmpty())
        #expect(store.isWorkspaceEmpty == false)
        #expect(store.clients.isEmpty == false)
        #expect(store.importSampleDataIfEmpty() == false)
    }

    @Test
    @MainActor
    func corruptedSnapshotRecoversToEmptyWorkspace() throws {
        let saveURL = try makeSaveURL()
        try Data("not-valid-json".utf8).write(to: saveURL, options: .atomic)

        let store = StudioStore(saveURL: saveURL)
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: saveURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )

        #expect(store.isWorkspaceEmpty)
        #expect(backupFiles.contains { $0.lastPathComponent.hasPrefix("studio-store-corrupted-") })
    }

    @Test
    func clientAttentionOnlyFlagsOverdueOrOutstanding() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_742_375_400)
        let baseClient = ClientRecord(
            name: "测试客户",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .discovery,
            tier: .standard,
            nextContactAt: now.addingTimeInterval(86_400)
        )

        let overdueTouchpoint = TouchpointRecord(
            title: "催回复",
            detailsText: "",
            dueAt: now.addingTimeInterval(-86_400),
            channel: .wechat,
            priority: .medium
        )

        #expect(
            ClientAttentionRules.needsAttention(
                client: baseClient,
                nextPendingTouchpoint: nil,
                outstandingValue: 0,
                now: now,
                calendar: calendar
            ) == false
        )
        #expect(
            ClientAttentionRules.needsAttention(
                client: baseClient,
                nextPendingTouchpoint: overdueTouchpoint,
                outstandingValue: 0,
                now: now,
                calendar: calendar
            )
        )
        #expect(
            ClientAttentionRules.needsAttention(
                client: baseClient,
                nextPendingTouchpoint: nil,
                outstandingValue: 1_200,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test
    func notificationManagerOnlySchedulesFutureReminders() {
        let now = Date(timeIntervalSince1970: 1_742_375_400)
        let manager = AppNotificationManager.shared
        let settings = AppSettings.default
        let booking = BookingRecord(
            title: "婚礼拍摄",
            category: .wedding,
            status: .confirmed,
            startAt: now.addingTimeInterval(86_400 * 2),
            endAt: now.addingTimeInterval(86_400 * 2 + 3_600),
            venue: "酒店",
            city: "上海",
            fee: 8_000,
            depositPaid: 2_000,
            deliverableText: "精修 60 张",
            notesText: "",
            reminderOffsets: [.threeDaysBefore, .oneDayBefore, .sameDayMorning, .twoHoursBefore]
        )

        #expect(manager.bookingReminderFireDate(for: booking, offset: .threeDaysBefore, settings: settings) < booking.startAt)
        #expect(manager.bookingReminderFireDate(for: booking, offset: .oneDayBefore, settings: settings) < booking.startAt)
        #expect(manager.bookingReminderFireDate(for: booking, offset: .sameDayMorning, settings: settings) < booking.startAt)
        #expect(manager.bookingReminderFireDate(for: booking, offset: .twoHoursBefore, settings: settings) < booking.startAt)
        #expect(manager.canScheduleNotification(fireDate: now.addingTimeInterval(30), now: now) == false)
        #expect(manager.canScheduleNotification(fireDate: now.addingTimeInterval(300), now: now))
    }

    @Test
    func templateReminderSuggestionsMatchLeadTime() {
        #expect(BookingReminderOffset.suggestedSelection(defaultReminderDays: 3) == BookingReminderOffset.defaultSelection)
        #expect(BookingReminderOffset.suggestedSelection(defaultReminderDays: 2) == [.oneDayBefore, .sameDayMorning, .twoHoursBefore])
        #expect(BookingReminderOffset.suggestedSelection(defaultReminderDays: 0) == [.sameDayMorning, .twoHoursBefore])
    }

    @Test
    func bookingDefaultTimeRoundsUpToNextHalfHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 9, minute: 41, second: 27))!

        let result = BookingDateDefaults.startDate(seedDate: nil, calendar: calendar, now: now)
        let components = calendar.dateComponents([.hour, .minute, .second], from: result)

        #expect(components.hour == 10)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test
    @MainActor
    func manualPaymentUpdatesReceivedAndOutstandingAmounts() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)
        let booking = BookingRecord(
            title: "回款测试",
            category: .portrait,
            status: .confirmed,
            startAt: .now.addingTimeInterval(86_400),
            endAt: .now.addingTimeInterval(90_000),
            venue: "影棚",
            city: "上海",
            fee: 3_200,
            depositPaid: 0,
            deliverableText: "精修 20 张",
            notesText: ""
        )

        store.upsert(booking: booking)
        store.upsert(payment: PaymentRecord(
            bookingID: booking.id,
            amount: 1_000,
            paymentType: .deposit,
            date: .now
        ))

        #expect(store.receivedAmount(for: booking) == 1_000)
        #expect(store.outstandingAmount(for: booking) == 2_200)
    }

    @Test
    @MainActor
    func settingsPersistenceKeepsNotificationToggle() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)

        var settings = store.settings
        settings.notificationsEnabled = false
        settings.defaultReminderHour = 9
        settings.themeStyle = .crystalPurple
        store.updateSettings(settings)
        store.flushPersistenceForTesting()

        let reloaded = StudioStore(saveURL: saveURL)
        #expect(reloaded.settings.notificationsEnabled == false)
        #expect(reloaded.settings.defaultReminderHour == 9)
        #expect(reloaded.settings.themeStyle == .crystalPurple)
    }

    @Test
    func appSettingsDecodeFallsBackToDefaultThemeForLegacyPayload() throws {
        let data = Data(
            """
            {
              "studioName": "旧版工作室",
              "contactPhone": "123456789",
              "defaultLocation": "上海",
              "defaultNotes": "",
              "defaultDepositRatio": 0.3,
              "defaultBalanceRule": "拍摄当天结清",
              "notificationsEnabled": true,
              "defaultReminderHour": 18,
              "remindOutstandingPayments": true,
              "remindFollowUps": true
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.themeStyle == .appleGreen)
        #expect(settings.iCloudSyncEnabled == false)
        #expect(settings.currencyCode == "CNY")
    }

    @Test
    @MainActor
    func touchpointReminderPreferencePersistsAcrossReload() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)
        let item = TouchpointRecord(
            title: "关闭提醒的跟进",
            detailsText: "测试",
            dueAt: .now.addingTimeInterval(86_400),
            channel: .wechat,
            priority: .medium,
            isSystemReminderEnabled: false
        )

        store.upsert(touchpoint: item)
        store.flushPersistenceForTesting()

        let reloaded = StudioStore(saveURL: saveURL)
        #expect(reloaded.touchpoint(id: item.id)?.isSystemReminderEnabled == false)
    }


    @Test
    @MainActor
    func restoringBackupWithoutAttachmentsClearsStaleLocalAttachmentFiles() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)
        let attachmentDirectory = saveURL.deletingLastPathComponent().appending(path: "Attachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: attachmentDirectory, withIntermediateDirectories: true)
        let staleFileURL = attachmentDirectory.appending(path: "stale.txt")
        try Data("stale".utf8).write(to: staleFileURL, options: .atomic)

        let backupURL = saveURL.deletingLastPathComponent().appending(path: "restore-no-attachments.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(StudioStoreSnapshot.empty).write(to: backupURL, options: .atomic)

        try store.restore(from: backupURL)

        #expect(FileManager.default.fileExists(atPath: staleFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: attachmentDirectory.path) == false)
    }

    @Test
    @MainActor
    func missingLocalAttachmentShowsAvailabilityMessage() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)
        let attachment = AttachmentRecord(
            category: .reference,
            title: "本地资料",
            localRelativePath: "Attachments/missing.pdf",
            mimeType: "application/pdf",
            byteCount: 128
        )

        store.upsert(attachment: attachment)
        store.flushPersistenceForTesting()

        let reloaded = StudioStore(saveURL: saveURL)
        guard let restoredAttachment = reloaded.attachments.first else {
            Issue.record("Expected restored attachment record")
            return
        }
        #expect(reloaded.attachmentFileURL(for: restoredAttachment) == nil)
        #expect(reloaded.attachmentAvailabilityMessage(for: restoredAttachment)?.contains("完整备份") == true)
    }

    @Test
    @MainActor
    func restoringForeignWorkspaceDoesNotReplaceCurrentOwnerOrKeepSyncEnabled() throws {
        let saveURL = try makeSaveURL()
        let store = StudioStore(saveURL: saveURL)
        let currentAuth = AuthProfile(appleUserID: "owner-A", email: "a@example.com", fullName: "Owner A")
        store.setAuthProfile(currentAuth)

        var currentSettings = store.settings
        currentSettings.iCloudSyncEnabled = true
        store.updateSettings(currentSettings)

        let foreignSnapshot = StudioStoreSnapshot(
            clients: [],
            bookings: [],
            touchpoints: [],
            payments: [],
            crewMembers: [],
            studioProfile: .empty,
            templates: [],
            settings: {
                var settings = AppSettings.default
                settings.iCloudSyncEnabled = true
                return settings
            }(),
            authProfile: AuthProfile(appleUserID: "owner-B", email: "b@example.com", fullName: "Owner B"),
            workspaceOwnerAppleUserID: "owner-B",
            lastModifiedAt: .now
        )
        let backupURL = saveURL.deletingLastPathComponent().appending(path: "foreign-backup.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(foreignSnapshot).write(to: backupURL, options: .atomic)

        try store.restore(from: backupURL)

        #expect(store.authProfile?.appleUserID == "owner-A")
        #expect(store.workspaceOwnerAppleUserID == "owner-A")
        #expect(store.settings.iCloudSyncEnabled == false)
    }

    private func makeSaveURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "studio-store.json")
    }
}
