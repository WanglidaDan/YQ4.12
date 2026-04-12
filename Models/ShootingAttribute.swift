import Foundation

enum ShootingAttribute: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo
    case video
    case videoLive
    case photoLive
    case edit
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: "照相"
        case .video: "录像"
        case .videoLive: "视频直播"
        case .photoLive: "照片直播"
        case .edit: "剪辑"
        case .color: "调色"
        }
    }

    var symbolName: String {
        switch self {
        case .photo: "camera.fill"
        case .video: "video.fill"
        case .videoLive: "antenna.radiowaves.left.and.right"
        case .photoLive: "photo.on.rectangle.angled"
        case .edit: "scissors"
        case .color: "paintbrush.pointed.fill"
        }
    }

    static func normalized(_ attributes: [ShootingAttribute]) -> [ShootingAttribute] {
        Self.allCases.filter { attributes.contains($0) }
    }

    static func defaultSelection(for category: ServiceCategory) -> [ShootingAttribute] {
        switch category {
        case .video, .documentaryFilm, .aerial:
            return [.video]
        case .event, .corporate, .commercial:
            return [.photo, .video]
        default:
            return [.photo]
        }
    }

    static func displayTitle(for attributes: [ShootingAttribute]) -> String {
        let titles = normalized(attributes).map(\.title)
        return titles.isEmpty ? "待补充" : titles.joined(separator: "、")
    }

    static func displaySymbolName(for attributes: [ShootingAttribute]) -> String {
        normalized(attributes).first?.symbolName ?? "camera.fill"
    }

    static func legacySelection(from rawValue: String) -> [ShootingAttribute] {
        if let attribute = ShootingAttribute(rawValue: rawValue) {
            return [attribute]
        }

        switch rawValue {
        case "retouch":
            return [.edit, .color]
        case "mixed":
            return [.photo, .video]
        default:
            return []
        }
    }
}
