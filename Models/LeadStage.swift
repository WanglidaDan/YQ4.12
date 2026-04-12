import Foundation

enum LeadStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case discovery
    case negotiating
    case booked
    case retained

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovery: "新线索"
        case .negotiating: "报价中"
        case .booked: "已成交"
        case .retained: "长期经营"
        }
    }
}
