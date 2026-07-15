import SwiftUI

enum AppTheme {
    private static var currentStyle: AppThemeStyle = .appleGreen

    static var background: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static var canvas: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    static var panel: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    static var panelStrong: Color {
        Color(uiColor: .systemBackground)
    }

    static var panelSoft: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    static var inputSurface: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    static var sheetBackground: Color {
        Color(uiColor: .systemBackground)
    }

    static var line: Color {
        Color(uiColor: .separator)
    }

    static var ink: Color {
        Color(uiColor: .label)
    }

    static var secondaryInk: Color {
        Color(uiColor: .secondaryLabel)
    }

    static var mutedInk: Color {
        Color(uiColor: .tertiaryLabel)
    }

    static var accent: Color {
        dynamic(light: palette.primaryLight, dark: palette.primaryDark)
    }

    static var accentDeep: Color {
        dynamic(light: palette.deepLight, dark: palette.deepDark)
    }

    static var accentSoft: Color {
        dynamic(
            light: palette.primaryLight.mixed(with: UIColor(hex: "#EEE9E0"), ratio: 0.72),
            dark: palette.primaryDark.mixed(with: UIColor(hex: "#2A302C"), ratio: 0.42)
        )
    }

    static var accentSurface: Color {
        dynamic(
            light: palette.primaryLight.mixed(with: UIColor.white, ratio: 0.88),
            dark: palette.primaryDark.mixed(with: UIColor(hex: "#1F2421"), ratio: 0.74)
        )
    }

    static var accentWarm: Color {
        dynamic(light: UIColor(hex: "#6C756E"), dark: UIColor(hex: "#A9B2AA"))
    }

    static var accentWarmDeep: Color {
        dynamic(light: UIColor(hex: "#4F5D52"), dark: UIColor(hex: "#C6CCC6"))
    }

    static var accentWarmSoft: Color {
        dynamic(light: UIColor(hex: "#EEF1EC"), dark: UIColor(hex: "#202822"))
    }

    static var accentRose: Color {
        dynamic(light: UIColor(hex: "#6C756E"), dark: UIColor(hex: "#A9B2AA"))
    }

    static var accentRoseSoft: Color {
        dynamic(light: UIColor(hex: "#EEF1EC"), dark: UIColor(hex: "#202822"))
    }

    static let info = Color(uiColor: .systemBlue)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let danger = Color(uiColor: .systemRed)
    static let priorityLow = dynamic(light: UIColor(hex: "#335B45"), dark: UIColor(hex: "#8FA891"))
    static let priorityMedium = dynamic(light: UIColor(hex: "#335B45"), dark: UIColor(hex: "#8FA891"))
    static let priorityHigh = dynamic(light: UIColor(hex: "#335B45"), dark: UIColor(hex: "#8FA891"))
    static let priorityUrgent = dynamic(light: UIColor(hex: "#335B45"), dark: UIColor(hex: "#8FA891"))

    static let cardShadow = dynamic(light: UIColor(hex: "#171E19").withAlphaComponent(0.075), dark: UIColor.black.withAlphaComponent(0.26))
    static let deepShadow = dynamic(light: UIColor(hex: "#101512").withAlphaComponent(0.14), dark: UIColor.black.withAlphaComponent(0.34))

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [panelStrong, panel],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: palette.deepLight, dark: UIColor(hex: "#233328")),
                dynamic(light: palette.primaryLight, dark: UIColor(hex: "#405545")),
                dynamic(light: UIColor(hex: "#B1BCA7"), dark: UIColor(hex: "#72866F"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var metallicGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#F8F4EE"), dark: UIColor(hex: "#272A27")),
                dynamic(light: UIColor(hex: "#E6DDD1"), dark: UIColor(hex: "#323631")),
                dynamic(light: UIColor(hex: "#D5C9BA"), dark: UIColor(hex: "#3B3F39"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var sheetGradient: LinearGradient {
        LinearGradient(
            colors: [sheetBackground, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func apply(_ style: AppThemeStyle) {
        currentStyle = style
    }

    private static var palette: AppThemePalette {
        currentStyle.palette
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}
