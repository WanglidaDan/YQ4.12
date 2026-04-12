import Foundation

enum BookingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case inquiry
    case tentative
    case confirmed
    case shooting
    case editing
    case delivered
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inquiry: "咨询中"
        case .tentative: "待确认"
        case .confirmed: "已确认"
        case .shooting: "拍摄中"
        case .editing: "后期中"
        case .delivered: "已交付"
        case .cancelled: "已取消"
        }
    }
}
