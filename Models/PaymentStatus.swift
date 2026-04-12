import Foundation

enum PaymentStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case unpaidDeposit
    case depositReceived
    case balanceDue
    case paidInFull
    case refunded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unpaidDeposit: "未收款"
        case .depositReceived: "部分已收"
        case .balanceDue: "待补尾款"
        case .paidInFull: "已结清"
        case .refunded: "已退款"
        }
    }
}
