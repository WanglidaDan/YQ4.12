import Foundation

enum TouchpointChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case wechat
    case phone
    case email
    case meeting
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wechat: "微信"
        case .phone: "电话"
        case .email: "邮件"
        case .meeting: "面谈"
        case .delivery: "交付"
        }
    }

    var symbolName: String {
        switch self {
        case .wechat: "message.fill"
        case .phone: "phone.fill"
        case .email: "envelope.fill"
        case .meeting: "person.2.fill"
        case .delivery: "shippingbox.fill"
        }
    }
}
