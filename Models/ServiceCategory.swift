import Foundation

enum ServiceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case wedding
    case engagement
    case travel
    case portrait
    case couple
    case bestie
    case maternity
    case newborn
    case children
    case family
    case graduation
    case pet
    case documentary
    case documentaryFilm
    case aerial
    case video
    case event
    case corporate
    case product
    case ecommerce
    case food
    case space
    case commercial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wedding: "婚礼"
        case .engagement: "求婚 / 订婚"
        case .travel: "旅拍"
        case .portrait: "肖像"
        case .couple: "情侣"
        case .bestie: "闺蜜"
        case .maternity: "孕妇"
        case .newborn: "新生儿"
        case .children: "儿童"
        case .family: "亲子 / 全家福"
        case .graduation: "毕业照"
        case .pet: "宠物"
        case .documentary: "跟拍 / 纪实"
        case .documentaryFilm: "纪录片摄像"
        case .aerial: "航拍"
        case .video: "视频拍摄"
        case .event: "活动 / 会议"
        case .corporate: "企业形象"
        case .product: "产品 / 静物"
        case .ecommerce: "电商服饰"
        case .food: "美食 / 餐饮"
        case .space: "空间 / 建筑"
        case .commercial: "商业广告"
        }
    }

    var symbolName: String {
        switch self {
        case .wedding: "heart.fill"
        case .engagement: "sparkles"
        case .travel: "airplane.departure"
        case .portrait: "person.crop.square"
        case .couple: "person.2.fill"
        case .bestie: "person.2.wave.2.fill"
        case .maternity: "figure.seated.side"
        case .newborn: "figure.and.child.holdinghands"
        case .children: "figure.play"
        case .family: "person.3.fill"
        case .graduation: "graduationcap.fill"
        case .pet: "pawprint.fill"
        case .documentary: "camera.aperture"
        case .documentaryFilm: "movieclapper.fill"
        case .aerial: "helicopter"
        case .video: "video.fill"
        case .event: "calendar.badge.clock"
        case .corporate: "person.3.sequence.fill"
        case .product: "shippingbox.fill"
        case .ecommerce: "bag.fill"
        case .food: "fork.knife"
        case .space: "building.2.fill"
        case .commercial: "megaphone.fill"
        }
    }
}
