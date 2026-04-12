import SwiftUI
import UIKit

struct ThemeSwatch: Hashable, Sendable {
    let name: String
    let hex: String
}

struct AppThemePalette {
    let primaryLight: UIColor
    let primaryDark: UIColor
    let deepLight: UIColor
    let deepDark: UIColor
    let softLight: UIColor
    let softDark: UIColor
    let surfaceLight: UIColor
    let surfaceDark: UIColor
    let previewSwatches: [ThemeSwatch]
}

extension UIColor {
    convenience init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(sanitized, radix: 16) ?? 0
        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    func mixed(with color: UIColor, ratio: CGFloat) -> UIColor {
        let normalizedRatio = min(max(ratio, 0), 1)
        var redA: CGFloat = 0
        var greenA: CGFloat = 0
        var blueA: CGFloat = 0
        var alphaA: CGFloat = 0
        var redB: CGFloat = 0
        var greenB: CGFloat = 0
        var blueB: CGFloat = 0
        var alphaB: CGFloat = 0

        getRed(&redA, green: &greenA, blue: &blueA, alpha: &alphaA)
        color.getRed(&redB, green: &greenB, blue: &blueB, alpha: &alphaB)

        return UIColor(
            red: redA + (redB - redA) * normalizedRatio,
            green: greenA + (greenB - greenA) * normalizedRatio,
            blue: blueA + (blueB - blueA) * normalizedRatio,
            alpha: alphaA + (alphaB - alphaA) * normalizedRatio
        )
    }
}
