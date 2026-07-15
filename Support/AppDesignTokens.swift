import SwiftUI

enum AppTypography {
    static let pageTitle = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let heroTitle = Font.system(.title, design: .default, weight: .semibold)
    static let sectionTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let rowTitle = Font.system(.body, design: .default, weight: .semibold)
    static let rowValue = Font.system(.callout, design: .default, weight: .semibold)
    static let sectionSubtitle = Font.system(.footnote, design: .default, weight: .medium)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let bodyStrong = Font.system(.body, design: .default, weight: .semibold)
    static let meta = Font.system(.footnote, design: .default, weight: .medium)
    static let small = Font.system(.caption, design: .default, weight: .medium)
    static let micro = Font.system(.caption2, design: .default, weight: .semibold)
    static let badge = Font.system(.caption, design: .default, weight: .semibold)
    static let data = Font.system(.title2, design: .default, weight: .semibold)
    static let dataCompact = Font.system(.title3, design: .default, weight: .semibold)
    static let icon = Font.system(.body, design: .default, weight: .semibold)
}

enum AppSpacing {
    static let page: CGFloat = 20
    static let section: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let content: CGFloat = 14
    static let tight: CGFloat = 8
    static let compact: CGFloat = 6
}

enum AppRadius {
    static let hero: CGFloat = 24
    static let card: CGFloat = 16
    static let control: CGFloat = 12
    static let row: CGFloat = 10
    static let badge: CGFloat = 8
}

enum AppShadow {
    static let cardRadius: CGFloat = 10
    static let cardY: CGFloat = 4
    static let heroRadius: CGFloat = 18
    static let heroY: CGFloat = 8
}
