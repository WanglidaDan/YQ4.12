import ActivityKit
import Foundation
import UIKit

struct BookingReminderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var clientName: String
        var clientPhoneNumber: String
        var venue: String
        var city: String
        var addressText: String
        var startAt: Date
        var endAt: Date
        var themeStyle: BookingReminderThemeStyle
    }

    var bookingID: String
}

enum BookingReminderThemeStyle: String, Codable, Hashable, Sendable {
    case appleGreen
    case qingLian
    case titianRed
    case naplesYellow
    case crystalPurple

    init(rawThemeStyle: String) {
        self = BookingReminderThemeStyle(rawValue: rawThemeStyle) ?? .appleGreen
    }

    var palette: BookingReminderThemePalette {
        switch self {
        case .appleGreen:
            BookingReminderThemePalette(
                primaryLight: UIColor(hex: "#31493C"),
                deepLight: UIColor(hex: "#1D2A21"),
                softLight: UIColor(hex: "#C9D3C3"),
                surfaceLight: UIColor(hex: "#F6F4F0")
            )
        case .qingLian:
            BookingReminderThemePalette(
                primaryLight: UIColor(hex: "#4F5E68"),
                deepLight: UIColor(hex: "#2A3338"),
                softLight: UIColor(hex: "#CBD3D8"),
                surfaceLight: UIColor(hex: "#F4F3F0")
            )
        case .titianRed:
            BookingReminderThemePalette(
                primaryLight: UIColor(hex: "#6F594D"),
                deepLight: UIColor(hex: "#43352D"),
                softLight: UIColor(hex: "#D7C7BB"),
                surfaceLight: UIColor(hex: "#F7F3EE")
            )
        case .naplesYellow:
            BookingReminderThemePalette(
                primaryLight: UIColor(hex: "#8A7458"),
                deepLight: UIColor(hex: "#514333"),
                softLight: UIColor(hex: "#DDD1C0"),
                surfaceLight: UIColor(hex: "#F8F5EF")
            )
        case .crystalPurple:
            BookingReminderThemePalette(
                primaryLight: UIColor(hex: "#58556A"),
                deepLight: UIColor(hex: "#343242"),
                softLight: UIColor(hex: "#CFCCDA"),
                surfaceLight: UIColor(hex: "#F5F3F0")
            )
        }
    }
}

struct BookingReminderThemePalette: Hashable, Sendable {
    let primaryLight: UIColor
    let deepLight: UIColor
    let softLight: UIColor
    let surfaceLight: UIColor
}
