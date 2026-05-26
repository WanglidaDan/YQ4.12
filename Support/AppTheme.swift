import SwiftUI

enum AppTheme {
    private static var currentStyle: AppThemeStyle = .appleGreen

    static var background: Color {
        dynamic(light: UIColor(hex: "#F5F3EF"), dark: UIColor(hex: "#111312"))
    }

    static var canvas: Color {
        dynamic(light: UIColor(hex: "#EFEEE9"), dark: UIColor(hex: "#151716"))
    }

    static var panel: Color {
        dynamic(light: UIColor(hex: "#FCFAF7"), dark: UIColor(hex: "#1A1D1B"))
    }

    static var panelStrong: Color {
        dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#202422"))
    }

    static var panelSoft: Color {
        dynamic(light: UIColor(hex: "#F3F0EA"), dark: UIColor(hex: "#171A18"))
    }

    static var inputSurface: Color {
        dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#242826"))
    }

    static var sheetBackground: Color {
        dynamic(light: UIColor(hex: "#FAF8F4"), dark: UIColor(hex: "#101211"))
    }

    static var line: Color {
        dynamic(light: UIColor(hex: "#D8D2C9"), dark: UIColor(hex: "#343936"))
    }

    static var ink: Color {
        dynamic(light: UIColor(hex: "#141715"), dark: UIColor(hex: "#F3F1ED"))
    }

    static var secondaryInk: Color {
        dynamic(light: UIColor(hex: "#56615B"), dark: UIColor(hex: "#C6CCC6"))
    }

    static var mutedInk: Color {
        dynamic(light: UIColor(hex: "#7A837D"), dark: UIColor(hex: "#929A94"))
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

    static let cardShadow = dynamic(light: UIColor(hex: "#171E19").withAlphaComponent(0.075), dark: UIColor.black.withAlphaComponent(0.26))
    static let deepShadow = dynamic(light: UIColor(hex: "#101512").withAlphaComponent(0.14), dark: UIColor.black.withAlphaComponent(0.34))

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#FCFAF6"), dark: UIColor(hex: "#101211")),
                dynamic(light: UIColor(hex: "#F4F1EB"), dark: UIColor(hex: "#151817")),
                dynamic(light: UIColor(hex: "#F7F4EF"), dark: UIColor(hex: "#1A1D1B"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#242826")),
                dynamic(light: UIColor(hex: "#FAF7F3"), dark: UIColor(hex: "#1F2220")),
                dynamic(light: UIColor(hex: "#F1EDE6"), dark: UIColor(hex: "#1A1D1B"))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
            colors: [
                dynamic(light: UIColor(hex: "#FFFFFF"), dark: UIColor(hex: "#181B19")),
                dynamic(light: UIColor(hex: "#F8F5EF"), dark: UIColor(hex: "#141716")),
                dynamic(light: UIColor(hex: "#EFEBE4"), dark: UIColor(hex: "#101211"))
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
