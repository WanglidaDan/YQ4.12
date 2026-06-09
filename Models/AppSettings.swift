import Foundation

struct CrewMemberRecord: Codable, Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var displayName: String
    var roleTitle: String
    var phone: String
    var email: String
    var notes: String
    var isArchived: Bool = false
    var createdAt: Date = .now
}

struct StudioProfile: Codable, Hashable, Sendable {
    var displayName: String
    var legalName: String
    var contactPhone: String
    var contactEmail: String
    var city: String
    var address: String
    var notes: String

    static let empty = StudioProfile(
        displayName: "",
        legalName: "",
        contactPhone: "",
        contactEmail: "",
        city: "",
        address: "",
        notes: ""
    )
}

struct AppSettings: Codable, Hashable, Sendable {
    static let supportedCurrencyCodes = ["CNY", "HKD", "MOP", "TWD", "SGD", "USD", "JPY", "EUR"]

    var studioName: String
    var contactPhone: String
    var currentMemberName: String
    var crewLensEnabled: Bool
    var currentCrewMemberID: UUID?
    var studioModeEnabled: Bool
    var defaultLocation: String
    var defaultNotes: String
    var defaultDepositRatio: Double
    var defaultBalanceRule: String
    var notificationsEnabled: Bool
    var defaultReminderHour: Int
    var remindOutstandingPayments: Bool
    var remindFollowUps: Bool
    var currencyCode: String
    var themeStyle: AppThemeStyle
    var iCloudSyncEnabled: Bool

    init(
        studioName: String,
        contactPhone: String,
        currentMemberName: String,
        crewLensEnabled: Bool,
        currentCrewMemberID: UUID? = nil,
        studioModeEnabled: Bool = true,
        defaultLocation: String,
        defaultNotes: String,
        defaultDepositRatio: Double,
        defaultBalanceRule: String,
        notificationsEnabled: Bool,
        defaultReminderHour: Int,
        remindOutstandingPayments: Bool,
        remindFollowUps: Bool,
        currencyCode: String = "CNY",
        themeStyle: AppThemeStyle,
        iCloudSyncEnabled: Bool
    ) {
        self.studioName = studioName
        self.contactPhone = contactPhone
        self.currentMemberName = currentMemberName
        self.crewLensEnabled = crewLensEnabled
        self.currentCrewMemberID = currentCrewMemberID
        self.studioModeEnabled = studioModeEnabled
        self.defaultLocation = defaultLocation
        self.defaultNotes = defaultNotes
        self.defaultDepositRatio = defaultDepositRatio
        self.defaultBalanceRule = defaultBalanceRule
        self.notificationsEnabled = notificationsEnabled
        self.defaultReminderHour = defaultReminderHour
        self.remindOutstandingPayments = remindOutstandingPayments
        self.remindFollowUps = remindFollowUps
        self.currencyCode = Self.normalizedCurrencyCode(currencyCode)
        self.themeStyle = themeStyle
        self.iCloudSyncEnabled = iCloudSyncEnabled
    }

    static let `default` = AppSettings(
        studioName: "",
        contactPhone: "",
        currentMemberName: "",
        crewLensEnabled: true,
        currentCrewMemberID: nil,
        studioModeEnabled: true,
        defaultLocation: "",
        defaultNotes: "",
        defaultDepositRatio: 0.3,
        defaultBalanceRule: "拍摄当天结清",
        notificationsEnabled: false,
        defaultReminderHour: 18,
        remindOutstandingPayments: true,
        remindFollowUps: true,
        currencyCode: "CNY",
        themeStyle: .appleGreen,
        iCloudSyncEnabled: false
    )
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case studioName
        case contactPhone
        case currentMemberName
        case crewLensEnabled
        case currentCrewMemberID
        case studioModeEnabled
        case defaultLocation
        case defaultNotes
        case defaultDepositRatio
        case defaultBalanceRule
        case notificationsEnabled
        case defaultReminderHour
        case remindOutstandingPayments
        case remindFollowUps
        case currencyCode
        case themeStyle
        case iCloudSyncEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studioName = try container.decode(String.self, forKey: .studioName)
        contactPhone = try container.decode(String.self, forKey: .contactPhone)
        currentMemberName = try container.decodeIfPresent(String.self, forKey: .currentMemberName) ?? ""
        crewLensEnabled = try container.decodeIfPresent(Bool.self, forKey: .crewLensEnabled) ?? true
        currentCrewMemberID = try container.decodeIfPresent(UUID.self, forKey: .currentCrewMemberID)
        studioModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .studioModeEnabled) ?? true
        defaultLocation = try container.decode(String.self, forKey: .defaultLocation)
        defaultNotes = try container.decode(String.self, forKey: .defaultNotes)
        defaultDepositRatio = try container.decode(Double.self, forKey: .defaultDepositRatio)
        defaultBalanceRule = try container.decode(String.self, forKey: .defaultBalanceRule)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        defaultReminderHour = try container.decode(Int.self, forKey: .defaultReminderHour)
        remindOutstandingPayments = try container.decode(Bool.self, forKey: .remindOutstandingPayments)
        remindFollowUps = try container.decode(Bool.self, forKey: .remindFollowUps)
        currencyCode = Self.normalizedCurrencyCode(
            try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "CNY"
        )
        themeStyle = try container.decodeIfPresent(AppThemeStyle.self, forKey: .themeStyle) ?? .appleGreen
        iCloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
    }

    static func normalizedCurrencyCode(_ rawValue: String) -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return supportedCurrencyCodes.contains(normalized) ? normalized : "CNY"
    }
}
