import Foundation

struct BookingTemplate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: ServiceCategory
    var defaultDurationHours: Int
    var defaultPrice: Double
    var defaultDepositRatio: Double
    var defaultReminderDays: Int
    var defaultDeliverableText: String
    var defaultNotesText: String
    var defaultShootingAttributes: [ShootingAttribute]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: ServiceCategory,
        defaultDurationHours: Int,
        defaultPrice: Double,
        defaultDepositRatio: Double,
        defaultReminderDays: Int,
        defaultDeliverableText: String,
        defaultNotesText: String,
        defaultShootingAttributes: [ShootingAttribute]? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultDurationHours = defaultDurationHours
        self.defaultPrice = defaultPrice
        self.defaultDepositRatio = defaultDepositRatio
        self.defaultReminderDays = defaultReminderDays
        self.defaultDeliverableText = defaultDeliverableText
        self.defaultNotesText = defaultNotesText
        self.defaultShootingAttributes = ShootingAttribute.normalized(defaultShootingAttributes ?? ShootingAttribute.defaultSelection(for: category))
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, defaultDurationHours, defaultPrice, defaultDepositRatio, defaultReminderDays, defaultDeliverableText, defaultNotesText, defaultShootingAttributes, createdAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case defaultShootingAttribute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ServiceCategory.self, forKey: .category)
        defaultDurationHours = try container.decode(Int.self, forKey: .defaultDurationHours)
        defaultPrice = try container.decode(Double.self, forKey: .defaultPrice)
        defaultDepositRatio = try container.decode(Double.self, forKey: .defaultDepositRatio)
        defaultReminderDays = try container.decode(Int.self, forKey: .defaultReminderDays)
        defaultDeliverableText = try container.decode(String.self, forKey: .defaultDeliverableText)
        defaultNotesText = try container.decode(String.self, forKey: .defaultNotesText)
        if let defaultShootingAttributes = try container.decodeIfPresent([ShootingAttribute].self, forKey: .defaultShootingAttributes) {
            self.defaultShootingAttributes = ShootingAttribute.normalized(defaultShootingAttributes)
        } else if let legacyRawValue = try legacyContainer.decodeIfPresent(String.self, forKey: .defaultShootingAttribute) {
            self.defaultShootingAttributes = ShootingAttribute.legacySelection(from: legacyRawValue)
        } else {
            self.defaultShootingAttributes = ShootingAttribute.defaultSelection(for: category)
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
