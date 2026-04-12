import Foundation
import Testing

@testable import YingQi

struct OverviewSnapshotBuilderTests {
    @Test
    func builderSummarizesTodayAndOutstandingValue() {
        let now = Date(timeIntervalSince1970: 1_741_824_000)
        let clientID = UUID()
        let bookingID = UUID()
        let client = ClientRecord(
            id: clientID,
            name: "测试客户",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .discovery,
            tier: .standard
        )
        let booking = BookingRecord(
            id: bookingID,
            title: "测试拍摄",
            category: .wedding,
            status: .confirmed,
            startAt: now.addingTimeInterval(3600),
            endAt: now.addingTimeInterval(7200),
            venue: "测试酒店",
            city: "上海",
            fee: 20_000,
            depositPaid: 8_000,
            deliverableText: "精修 100 张",
            notesText: "测试",
            clientID: clientID
        )
        let touchpoint = TouchpointRecord(
            title: "发送确认单",
            detailsText: "今天内发送",
            dueAt: now.addingTimeInterval(1800),
            channel: .wechat,
            priority: .urgent,
            clientID: clientID,
            bookingID: bookingID
        )
        let payment = PaymentRecord(
            bookingID: bookingID,
            amount: 8_000,
            paymentType: .deposit,
            date: now
        )

        let snapshot = OverviewSnapshotBuilder(now: now).build(
            clients: [client],
            bookings: [booking],
            touchpoints: [touchpoint],
            payments: [payment]
        )

        #expect(snapshot.nextBookings.count == 1)
        #expect(snapshot.urgentTouchpoints.count == 1)
        #expect(snapshot.bookingSections.first?.title == "最近 3 天")
        #expect(snapshot.metrics.first(where: { $0.id == "balance" })?.value == AppFormatters.currency(12_000))
    }

    @Test
    func appFormatterSearchMatchesMultipleKeywords() {
        #expect(AppFormatters.matchesSearch("上海 婚礼", terms: ["上海外滩婚礼", "客片交付"]))
        #expect(AppFormatters.matchesSearch("深圳", terms: ["上海外滩婚礼"]) == false)
    }

    @Test
    func appFormatterUsesChineseDatePresentation() {
        let date = Date(timeIntervalSince1970: 1_742_348_400) // 2025-03-19 10:00:00 UTC

        #expect(AppFormatters.day(date).contains("月"))
        #expect(AppFormatters.day(date).contains("周"))
        #expect(AppFormatters.shortDate(date).contains("年"))
        #expect(AppFormatters.shortMonthDay(date).contains("月"))
        #expect(AppFormatters.monthYear(date).contains("年"))
        #expect(AppFormatters.timeRange(start: date, end: date.addingTimeInterval(5400)).contains(":"))
        #expect(AppFormatters.timeRange(start: date, end: date.addingTimeInterval(5400)).contains("AM") == false)
        #expect(AppFormatters.timeRange(start: date, end: date.addingTimeInterval(5400)).contains("PM") == false)
    }

    @Test
    @MainActor
    func deletingBookingClearsClientAssociation() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "阿明",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "小红书",
            notesText: "",
            stage: .discovery,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "婚礼跟拍",
            category: .wedding,
            status: .confirmed,
            startAt: .now.addingTimeInterval(3600),
            endAt: .now.addingTimeInterval(7200),
            venue: "酒店",
            city: "上海",
            fee: 6000,
            depositPaid: 2000,
            deliverableText: "精修 60 张",
            notesText: "",
            clientID: client.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)
        store.deleteBooking(booking.id)

        #expect(store.booking(id: booking.id) == nil)
    }

    @Test
    @MainActor
    func deletingLastDeliveredBookingRecomputesClientStageToDiscovery() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "阶段回算客户",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .retained,
            stageMode: .automatic,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "唯一历史订单",
            category: .portrait,
            status: .delivered,
            startAt: .now.addingTimeInterval(-86_400),
            endAt: .now.addingTimeInterval(-82_800),
            venue: "摄影棚",
            city: "上海",
            fee: 5_000,
            depositPaid: 5_000,
            deliverableText: "精修 18 张",
            notesText: "",
            clientID: client.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)
        store.deleteBooking(booking.id)

        #expect(store.client(id: client.id)?.stage == .discovery)
    }


    @Test
    @MainActor
    func archivingLastDeliveredBookingAlsoRecomputesClientStageToDiscovery() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "归档阶段客户",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .retained,
            stageMode: .automatic,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "已交付历史订单",
            category: .portrait,
            status: .delivered,
            startAt: .now.addingTimeInterval(-86_400),
            endAt: .now.addingTimeInterval(-82_800),
            venue: "摄影棚",
            city: "上海",
            fee: 5_000,
            depositPaid: 5_000,
            deliverableText: "精修 18 张",
            notesText: "",
            clientID: client.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)
        store.archiveBooking(booking.id)

        #expect(store.client(id: client.id)?.stage == .discovery)
    }

    @Test
    @MainActor
    func deletingBookingRemovesTouchpointsWithoutAnyRemainingAssociation() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let booking = BookingRecord(
            title: "孤儿清理订单",
            category: .commercial,
            status: .confirmed,
            startAt: .now.addingTimeInterval(3_600),
            endAt: .now.addingTimeInterval(7_200),
            venue: "棚内",
            city: "杭州",
            fee: 7_000,
            depositPaid: 1_000,
            deliverableText: "产品图",
            notesText: ""
        )
        let orphanTouchpoint = TouchpointRecord(
            title: "仅关联订单",
            detailsText: "",
            dueAt: .now.addingTimeInterval(1_800),
            channel: .wechat,
            priority: .medium,
            clientID: nil,
            bookingID: booking.id
        )

        store.upsert(booking: booking)
        store.upsert(touchpoint: orphanTouchpoint)
        store.deleteBooking(booking.id)

        #expect(store.touchpoint(id: orphanTouchpoint.id) == nil)
    }

    @Test
    @MainActor
    func archivingAndRestoringRecordsMovesThemBetweenScopes() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "归档客户",
            city: "杭州",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .discovery,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "归档订单",
            category: .portrait,
            status: .confirmed,
            startAt: .now.addingTimeInterval(3_600),
            endAt: .now.addingTimeInterval(7_200),
            venue: "摄影棚",
            city: "杭州",
            fee: 3_600,
            depositPaid: 1_000,
            deliverableText: "精修 20 张",
            notesText: "",
            clientID: client.id
        )
        let touchpoint = TouchpointRecord(
            title: "拍前确认",
            detailsText: "",
            dueAt: .now.addingTimeInterval(1_800),
            channel: .wechat,
            priority: .medium,
            clientID: client.id,
            bookingID: booking.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)
        store.upsert(touchpoint: touchpoint)

        store.archiveClient(client.id)
        store.archiveBooking(booking.id)
        store.archiveTouchpoint(touchpoint.id)

        #expect(store.activeClients.isEmpty)
        #expect(store.archivedClients.count == 1)
        #expect(store.activeBookings.isEmpty)
        #expect(store.archivedBookings.count == 1)
        #expect(store.archivedTouchpoints.count == 1)

        store.restoreClient(client.id)
        store.restoreBooking(booking.id)
        store.restoreTouchpoint(touchpoint.id)

        #expect(store.activeClients.count == 1)
        #expect(store.archivedClients.isEmpty)
        #expect(store.activeBookings.count == 1)
        #expect(store.archivedBookings.isEmpty)
        #expect(store.archivedTouchpoints.isEmpty)
    }

    @Test
    @MainActor
    func manualClientStageIsNotOverwrittenByBookingUpdates() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "手动阶段客户",
            city: "上海",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .retained,
            stageMode: .manual,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "手动阶段订单",
            category: .portrait,
            status: .inquiry,
            startAt: .now.addingTimeInterval(3_600),
            endAt: .now.addingTimeInterval(7_200),
            venue: "摄影棚",
            city: "上海",
            fee: 3_000,
            depositPaid: 0,
            deliverableText: "精修 12 张",
            notesText: "",
            clientID: client.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)

        #expect(store.client(id: client.id)?.stage == .retained)
    }

    @Test
    @MainActor
    func deletingClientWithHistoryArchivesInsteadOfRemoving() {
        let store = StudioStore(saveURL: try! makeSaveURL())
        let client = ClientRecord(
            name: "有历史客户",
            city: "杭州",
            phoneNumber: "123456789",
            sourceChannel: "微信",
            notesText: "",
            stage: .booked,
            tier: .standard
        )
        let booking = BookingRecord(
            title: "历史订单",
            category: .wedding,
            status: .confirmed,
            startAt: .now.addingTimeInterval(3_600),
            endAt: .now.addingTimeInterval(7_200),
            venue: "酒店",
            city: "杭州",
            fee: 8_000,
            depositPaid: 2_000,
            deliverableText: "精修 80 张",
            notesText: "",
            clientID: client.id
        )

        store.upsert(client: client)
        store.upsert(booking: booking)
        let outcome = store.deleteClient(client.id)

        #expect(outcome == .archivedToPreserveHistory)
        #expect(store.client(id: client.id)?.isArchived == true)
    }

    @Test
    @MainActor
    func legacyDepositMigratesIntoPaymentRecords() throws {
        let saveURL = try makeSaveURL()
        let booking = BookingRecord(
            title: "迁移订单",
            category: .wedding,
            status: .confirmed,
            startAt: .now.addingTimeInterval(86_400),
            endAt: .now.addingTimeInterval(90_000),
            venue: "酒店",
            city: "上海",
            fee: 10_000,
            depositPaid: 2_000,
            deliverableText: "精修 80 张",
            notesText: ""
        )
        let snapshot = StudioStoreSnapshot(
            version: 1,
            clients: [],
            bookings: [booking],
            touchpoints: [],
            payments: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: saveURL, options: .atomic)

        let store = StudioStore(saveURL: saveURL)

        #expect(store.payments(for: booking.id).count == 1)
        #expect(store.payments(for: booking.id).first?.paymentType == .deposit)
        #expect(store.paymentStatus(for: store.booking(id: booking.id)!) == .depositReceived)
    }

    private func makeSaveURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "studio-store.json")
    }

}
