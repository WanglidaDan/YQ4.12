import ActivityKit
import Foundation

struct BookingReminderActivityManager {
    static let shared = BookingReminderActivityManager()

    /// 灵动岛 / 锁屏实时活动只在真正临近拍摄时出现。
    /// 避免用户打开 App 后退出就立刻常驻显示。
    private let liveActivityLeadTime: TimeInterval = 24 * 60 * 60

    func sync(
        bookings: [BookingRecord],
        clients: [ClientRecord],
        themeStyle: AppThemeStyle,
        now: Date = .now
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let clientLookup = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
        let eligibleBookings = bookings.filter { booking in
            isEligibleForLiveActivity(booking, now: now)
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
                } else {
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

    private func isEligibleForLiveActivity(_ booking: BookingRecord, now: Date) -> Bool {
        guard booking.isArchived == false,
              booking.status != .cancelled,
              booking.status != .delivered,
              booking.reminderOffsets.isEmpty == false
        else { return false }

        // 拍摄结束后立即收起。
        guard booking.endAt > now else { return false }

        let secondsUntilStart = booking.startAt.timeIntervalSince(now)

        // 已经开拍但未结束时保留，方便锁屏继续显示地点、客户和导航。
        if secondsUntilStart <= 0 {
            return true
        }

        // 只在拍摄前 24 小时内出现。更早的档期只存在于 App 内，不占用灵动岛。
        return secondsUntilStart <= liveActivityLeadTime
    }

    private static func makeContentState(
        for booking: BookingRecord,
        clients: [UUID: ClientRecord],
        themeStyle: AppThemeStyle
    ) -> BookingReminderActivityAttributes.ContentState {
        let client = booking.clientID.flatMap { clients[$0] }
        return BookingReminderActivityAttributes.ContentState(
            title: booking.title,
            clientName: client?.name ?? "未绑定客户",
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
