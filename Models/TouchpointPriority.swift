import Foundation

enum TouchpointPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .urgent: "紧急"
        }
    }
}
