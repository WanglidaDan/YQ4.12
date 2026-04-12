import Foundation
import UIKit

enum AppThemeStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case appleGreen
    case qingLian
    case titianRed
    case naplesYellow
    case crystalPurple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleGreen: "主推绿影"
        case .qingLian: "青莲雅调"
        case .titianRed: "提香暖调"
        case .naplesYellow: "神仙黄调"
        case .crystalPurple: "晶石紫调"
        }
    }

    var subtitle: String {
        switch self {
        case .appleGreen: "苹果绿 / 荔枝白 / 深灰"
        case .qingLian: "青莲 / 丁香色 / 白藤色"
        case .titianRed: "提香红 / 路易威登棕 / 米汤娇"
        case .naplesYellow: "那不勒斯黄 / 荷花白 / 路易威登棕"
        case .crystalPurple: "晶石紫 / 象牙白 / 白藤色"
        }
    }

    var palette: AppThemePalette {
        switch self {
        case .appleGreen:
            AppThemePalette(
                primaryLight: UIColor(hex: "#31493C"),
                primaryDark: UIColor(hex: "#8EA88F"),
                deepLight: UIColor(hex: "#1D2A21"),
                deepDark: UIColor(hex: "#D6E0D4"),
                softLight: UIColor(hex: "#C9D3C3"),
                softDark: UIColor(hex: "#2A352D"),
                surfaceLight: UIColor(hex: "#F6F4F0"),
                surfaceDark: UIColor(hex: "#191B1A"),
                previewSwatches: [
                    ThemeSwatch(name: "墨绿", hex: "#31493C"),
                    ThemeSwatch(name: "冷白", hex: "#F6F4F0"),
                    ThemeSwatch(name: "暖灰", hex: "#C9D3C3")
                ]
            )
        case .qingLian:
            AppThemePalette(
                primaryLight: UIColor(hex: "#4F5E68"),
                primaryDark: UIColor(hex: "#A9B5BE"),
                deepLight: UIColor(hex: "#2A3338"),
                deepDark: UIColor(hex: "#D4DDE2"),
                softLight: UIColor(hex: "#CBD3D8"),
                softDark: UIColor(hex: "#293138"),
                surfaceLight: UIColor(hex: "#F4F3F0"),
                surfaceDark: UIColor(hex: "#1A1B1C"),
                previewSwatches: [
                    ThemeSwatch(name: "灰蓝", hex: "#4F5E68"),
                    ThemeSwatch(name: "冷白", hex: "#F4F3F0"),
                    ThemeSwatch(name: "雾灰", hex: "#CBD3D8")
                ]
            )
        case .titianRed:
            AppThemePalette(
                primaryLight: UIColor(hex: "#6F594D"),
                primaryDark: UIColor(hex: "#B8A393"),
                deepLight: UIColor(hex: "#43352D"),
                deepDark: UIColor(hex: "#E0D4CB"),
                softLight: UIColor(hex: "#D7C7BB"),
                softDark: UIColor(hex: "#352A25"),
                surfaceLight: UIColor(hex: "#F7F3EE"),
                surfaceDark: UIColor(hex: "#1B1A19"),
                previewSwatches: [
                    ThemeSwatch(name: "暖褐", hex: "#6F594D"),
                    ThemeSwatch(name: "纸米白", hex: "#F7F3EE"),
                    ThemeSwatch(name: "砂灰", hex: "#D7C7BB")
                ]
            )
        case .naplesYellow:
            AppThemePalette(
                primaryLight: UIColor(hex: "#8A7458"),
                primaryDark: UIColor(hex: "#C5B39A"),
                deepLight: UIColor(hex: "#514333"),
                deepDark: UIColor(hex: "#E4DACD"),
                softLight: UIColor(hex: "#DDD1C0"),
                softDark: UIColor(hex: "#3A3128"),
                surfaceLight: UIColor(hex: "#F8F5EF"),
                surfaceDark: UIColor(hex: "#1C1B19"),
                previewSwatches: [
                    ThemeSwatch(name: "米棕", hex: "#8A7458"),
                    ThemeSwatch(name: "纸白", hex: "#F8F5EF"),
                    ThemeSwatch(name: "暖米", hex: "#DDD1C0")
                ]
            )
        case .crystalPurple:
            AppThemePalette(
                primaryLight: UIColor(hex: "#58556A"),
                primaryDark: UIColor(hex: "#B5B2C2"),
                deepLight: UIColor(hex: "#343242"),
                deepDark: UIColor(hex: "#DDD9E7"),
                softLight: UIColor(hex: "#CFCCDA"),
                softDark: UIColor(hex: "#2C2A33"),
                surfaceLight: UIColor(hex: "#F5F3F0"),
                surfaceDark: UIColor(hex: "#19191B"),
                previewSwatches: [
                    ThemeSwatch(name: "石墨紫", hex: "#58556A"),
                    ThemeSwatch(name: "冷白", hex: "#F5F3F0"),
                    ThemeSwatch(name: "雾紫灰", hex: "#CFCCDA")
                ]
            )
        }
    }
}
