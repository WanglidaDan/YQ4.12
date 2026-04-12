import Foundation

enum PaymentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case deposit
    case balance
    case refund
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deposit: "定金"
        case .balance: "尾款"
        case .refund: "退款"
        case .custom: "其他"
        }
    }
}
