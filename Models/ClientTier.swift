import Foundation

enum ClientTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case focus
    case signature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准"
        case .focus: "重点"
        case .signature: "签名客户"
        }
    }
}
