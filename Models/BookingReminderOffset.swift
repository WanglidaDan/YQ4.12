import Foundation

enum BookingReminderOffset: String, Codable, CaseIterable, Identifiable, Sendable {
    case threeDaysBefore
    case oneDayBefore
    case sameDayMorning
    case twoHoursBefore

    static let defaultSelection: [BookingReminderOffset] = [
        .threeDaysBefore,
        .oneDayBefore,
        .sameDayMorning,
        .twoHoursBefore
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeDaysBefore: "提前 3 天"
        case .oneDayBefore: "提前 1 天"
        case .sameDayMorning: "拍摄当天"
        case .twoHoursBefore: "开拍前 2 小时"
        }
    }

    var shortTitle: String {
        switch self {
        case .threeDaysBefore: "3 天前"
        case .oneDayBefore: "1 天前"
        case .sameDayMorning: "当天"
        case .twoHoursBefore: "前 2 小时"
        }
    }

    var symbolName: String {
        switch self {
        case .threeDaysBefore: "calendar.badge.clock"
        case .oneDayBefore: "bell.badge"
        case .sameDayMorning: "sun.max.fill"
        case .twoHoursBefore: "timer"
        }
    }

    var sortOrder: Int {
        switch self {
        case .threeDaysBefore: 0
        case .oneDayBefore: 1
        case .sameDayMorning: 2
        case .twoHoursBefore: 3
        }
    }

    static func normalized(_ offsets: [BookingReminderOffset]) -> [BookingReminderOffset] {
        Array(Set(offsets)).sorted { $0.sortOrder < $1.sortOrder }
    }

    static func suggestedSelection(defaultReminderDays: Int) -> [BookingReminderOffset] {
        switch defaultReminderDays {
        case 3...:
            defaultSelection
        case 1...2:
            [.oneDayBefore, .sameDayMorning, .twoHoursBefore]
        default:
            [.sameDayMorning, .twoHoursBefore]
        }
    }
}
