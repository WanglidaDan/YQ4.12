import ActivityKit
import Foundation

struct BookingReminderActivityManager {
    static let shared = BookingReminderActivityManager()

    private let lookAheadWindow: TimeInterval = 3 * 24 * 60 * 60

    func sync(
        bookings: [BookingRecord],
        clients: [ClientRecord],
        themeStyle: AppThemeStyle,
        now: Date = .now
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let clientLookup = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
        let eligibleBookings = bookings.filter { booking in
            booking.isArchived == false &&
            booking.reminderOffsets.isEmpty == false &&
            booking.startAt > now &&
            booking.startAt <= now.addingTimeInterval(lookAheadWindow) &&
            booking.status != .cancelled &&
            booking.status != .delivered
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
                            staleDate: booking.startAt
                        )
                    )
                } else {
                    let attributes = BookingReminderActivityAttributes(bookingID: booking.id.uuidString)
                    _ = try? Activity.request(
                        attributes: attributes,
                        content: ActivityContent(
                            state: state,
                            staleDate: booking.startAt
                        ),
                        pushType: nil
                    )
                }
            }
        }
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
