import ActivityKit
import Foundation

struct BookingReminderActivityManager {
    static let shared = BookingReminderActivityManager()

    /// 灵动岛 / 锁屏实时活动只在真正临近拍摄时出现。
    /// 关键原则：普通打开 App、加载数据、刷新缓存时，只允许更新/结束已有实时活动，不主动新建。
    private let liveActivityLeadTime: TimeInterval = 24 * 60 * 60

    func sync(
        bookings: [BookingRecord],
        clients: [ClientRecord],
        themeStyle: AppThemeStyle,
        now: Date = .now,
        allowStartingNewActivities: Bool = false
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let clientLookup = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
        let eligibleBookings = bookings.filter { booking in
            isEligibleForLiveActivity(booking, clients: clientLookup, now: now)
        }

        Task {
            let currentActivities = Activity<BookingReminderActivityAttributes>.activities
            let eligibleIDs = Set(eligibleBookings.map(\.id.uuidString))

            for activity in currentActivities where eligibleIDs.contains(activity.attributes.bookingID) == false {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            for booking in eligibleBookings {
                let state = Self.makeContentState(
                    for: booking,
                    clients: clientLookup,
                    themeStyle: themeStyle
                )

                if let existing = currentActivities.first(where: { $0.attributes.bookingID == booking.id.uuidString }) {
                    await existing.update(
                        ActivityContent(
                            state: state,
                            staleDate: booking.endAt
                        )
                    )
                } else if allowStartingNewActivities {
                    let attributes = BookingReminderActivityAttributes(bookingID: booking.id.uuidString)
                    _ = try? Activity.request(
                        attributes: attributes,
                        content: ActivityContent(
                            state: state,
                            staleDate: booking.endAt
                        ),
                        pushType: nil
                    )
                }
            }
        }
    }

    /// 只有用户明确保存/更新档期后，才允许主动拉起新的实时活动。
    /// App 启动、切回前台、数据归一化等被动刷新，不调用这个入口。
    func startIfEligible(
        booking: BookingRecord,
        clients: [ClientRecord],
        themeStyle: AppThemeStyle,
        now: Date = .now
    ) {
        sync(
            bookings: [booking],
            clients: clients,
            themeStyle: themeStyle,
            now: now,
            allowStartingNewActivities: true
        )
    }

    private func isEligibleForLiveActivity(_ booking: BookingRecord, clients: [UUID: ClientRecord], now: Date) -> Bool {
        guard booking.isArchived == false,
              booking.status != .cancelled,
              booking.status != .delivered,
              booking.reminderOffsets.isEmpty == false
        else { return false }

        // 未绑定客户、客户被删除/归档、客户姓名为空，都不显示灵动岛/锁屏卡片。
        guard let clientID = booking.clientID,
              let client = clients[clientID],
              client.isArchived == false,
              client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else { return false }

        // 拍摄结束后立即收起。
        guard booking.endAt > now else { return false }

        let secondsUntilStart = booking.startAt.timeIntervalSince(now)

        // 已经开拍但未结束时保留，方便锁屏继续显示地点、客户和导航。
        if secondsUntilStart <= 0 {
            return true
        }

        // 只在拍摄前 24 小时内允许显示。更早的档期只存在于 App 内，不占用灵动岛。
        return secondsUntilStart <= liveActivityLeadTime
    }

    private static func makeContentState(
        for booking: BookingRecord,
        clients: [UUID: ClientRecord],
        themeStyle: AppThemeStyle
    ) -> BookingReminderActivityAttributes.ContentState {
        let client = booking.clientID.flatMap { clients[$0] }
        let clientName = client?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return BookingReminderActivityAttributes.ContentState(
            title: booking.title,
            clientName: clientName,
            clientPhoneNumber: AppFormatters.sanitizedPhoneNumber(client?.phoneNumber ?? ""),
            venue: booking.venue,
            city: booking.city,
            addressText: booking.addressText,
            startAt: booking.startAt,
            endAt: booking.endAt,
            themeStyle: BookingReminderThemeStyle(rawThemeStyle: themeStyle.rawValue)
        )
    }
}
