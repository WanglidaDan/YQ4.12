import SwiftUI

enum AppTheme {
    private static var currentStyle: AppThemeStyle = .appleGreen

    static var background: Color {
        dynamic(light: UIColor(hex: "#F4F2EE"), dark: UIColor(hex: "#141514"))
    }

    static var canvas: Color {
        dynamic(light: UIColor(hex: "#F0EEEA"), dark: UIColor(hex: "#171918"))
    }

    static var panel: Color {
        dynamic(light: UIColor(hex: "#FBFAF7"), dark: UIColor(hex: "#1B1D1C"))
    }

    static var panelStrong: Color {
        dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#202322"))
    }

    static var panelSoft: Color {
        dynamic(light: UIColor(hex: "#F2EFEB"), dark: UIColor(hex: "#171918"))
    }

    static var inputSurface: Color {
        dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#242725"))
    }

    static var sheetBackground: Color {
        dynamic(light: UIColor(hex: "#FAF8F4"), dark: UIColor(hex: "#111211"))
    }

    static var line: Color {
        dynamic(light: UIColor(hex: "#D9D5CF"), dark: UIColor(hex: "#343734"))
    }

    static var ink: Color {
        dynamic(light: UIColor(hex: "#161816"), dark: UIColor(hex: "#F2F1EE"))
    }

    static var secondaryInk: Color {
        dynamic(light: UIColor(hex: "#55605A"), dark: UIColor(hex: "#C4CAC4"))
    }

    static var mutedInk: Color {
        dynamic(light: UIColor(hex: "#7A817B"), dark: UIColor(hex: "#909791"))
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
        dynamic(light: UIColor(hex: "#C8B39A"), dark: UIColor(hex: "#A88F76"))
    }

    static var accentWarmDeep: Color {
        dynamic(light: UIColor(hex: "#89715A"), dark: UIColor(hex: "#C6B198"))
    }

    static var accentWarmSoft: Color {
        dynamic(light: UIColor(hex: "#F1E7DB"), dark: UIColor(hex: "#2E2924"))
    }

    static var accentRose: Color {
        dynamic(light: UIColor(hex: "#857D78"), dark: UIColor(hex: "#C0B8B2"))
    }

    static var accentRoseSoft: Color {
        dynamic(light: UIColor(hex: "#F1ECE7"), dark: UIColor(hex: "#262320"))
    }

    static let info = dynamic(light: UIColor(hex: "#64758A"), dark: UIColor(hex: "#A5B5C4"))
    static let success = dynamic(light: UIColor(hex: "#50715C"), dark: UIColor(hex: "#8FA891"))
    static let warning = dynamic(light: UIColor(hex: "#C57A36"), dark: UIColor(hex: "#E0A15E"))
    static let danger = dynamic(light: UIColor(hex: "#B44C56"), dark: UIColor(hex: "#E07A84"))
    static let priorityLow = dynamic(light: UIColor(hex: "#4E8B6B"), dark: UIColor(hex: "#8EB79D"))
    static let priorityMedium = dynamic(light: UIColor(hex: "#D19A5E"), dark: UIColor(hex: "#E6BD84"))
    static let priorityHigh = dynamic(light: UIColor(hex: "#C9772F"), dark: UIColor(hex: "#E19A57"))
    static let priorityUrgent = dynamic(light: UIColor(hex: "#A2465C"), dark: UIColor(hex: "#D97B93"))

    static let cardShadow = dynamic(light: UIColor(hex: "#171E19").withAlphaComponent(0.06), dark: UIColor.black.withAlphaComponent(0.24))
    static let deepShadow = dynamic(light: UIColor(hex: "#101512").withAlphaComponent(0.12), dark: UIColor.black.withAlphaComponent(0.32))

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#FAF8F4"), dark: UIColor(hex: "#121312")),
                dynamic(light: UIColor(hex: "#F3F1EC"), dark: UIColor(hex: "#171918")),
                dynamic(light: UIColor(hex: "#F6F4F0"), dark: UIColor(hex: "#1A1C1B"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#242725")),
                dynamic(light: UIColor(hex: "#FAF8F5"), dark: UIColor(hex: "#1F2120")),
                dynamic(light: UIColor(hex: "#F3F0EB"), dark: UIColor(hex: "#1B1D1C"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: palette.deepLight, dark: UIColor(hex: "#243228")),
                dynamic(light: palette.primaryLight, dark: UIColor(hex: "#405244")),
                dynamic(light: UIColor(hex: "#A8B59E"), dark: UIColor(hex: "#6E816D"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var metallicGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#F7F3EE"), dark: UIColor(hex: "#262825")),
                dynamic(light: UIColor(hex: "#E5DED4"), dark: UIColor(hex: "#32342F")),
                dynamic(light: UIColor(hex: "#D6CDC1"), dark: UIColor(hex: "#3A3D37"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var sheetGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#181A19")),
                dynamic(light: UIColor(hex: "#F7F5F0"), dark: UIColor(hex: "#141615")),
                dynamic(light: UIColor(hex: "#F0EEE9"), dark: UIColor(hex: "#101110"))
            ],
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
