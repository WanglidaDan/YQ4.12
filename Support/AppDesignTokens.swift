import SwiftUI

enum AppTypography {
    static let pageTitle = Font.system(size: 32, weight: .bold, design: .default)
    static let heroTitle = Font.system(size: 30, weight: .bold, design: .default)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .default)
    static let sectionSubtitle = Font.system(size: 13, weight: .medium, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyStrong = Font.system(size: 16, weight: .semibold, design: .default)
    static let meta = Font.system(size: 13, weight: .medium, design: .default)
    static let badge = Font.system(size: 12, weight: .semibold, design: .default)
    static let data = Font.system(size: 26, weight: .bold, design: .rounded)
    static let dataCompact = Font.system(size: 20, weight: .bold, design: .rounded)
}

enum AppSpacing {
    static let page: CGFloat = 20
    static let section: CGFloat = 18
    static let cardPadding: CGFloat = 20
    static let content: CGFloat = 14
    static let tight: CGFloat = 8
    static let compact: CGFloat = 6
}

enum AppRadius {
    static let hero: CGFloat = 28
    static let card: CGFloat = 22
    static let control: CGFloat = 16
    static let row: CGFloat = 14
    static let badge: CGFloat = 10
}

enum AppShadow {
    static let cardRadius: CGFloat = 10
    static let cardY: CGFloat = 4
    static let heroRadius: CGFloat = 18
    static let heroY: CGFloat = 10
}
