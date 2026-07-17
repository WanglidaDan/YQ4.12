import Foundation

enum BookingDateDefaults {
    static func startDate(
        seedDate: Date?,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Date {
        if let seedDate {
            return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: seedDate) ?? seedDate
        }

        guard let hour = calendar.dateInterval(of: .hour, for: now) else { return now }
        let halfHour = hour.start.addingTimeInterval(30 * 60)
        return now < halfHour ? halfHour : hour.end
    }
}
