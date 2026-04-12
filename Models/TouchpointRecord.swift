import Foundation

enum TouchpointSource: String, Codable, Hashable, Sendable {
    case manual
    case systemPreShootConfirmation
}

struct TouchpointRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var detailsText: String
    var dueAt: Date
    var channel: TouchpointChannel
    var priority: TouchpointPriority
    var isComplete: Bool
    var completedAt: Date?
    var createdAt: Date
    var clientID: UUID?
    var bookingID: UUID?
    var isArchived: Bool
    var archivedAt: Date?
    var isSystemReminderEnabled: Bool
    var source: TouchpointSource

    init(
        id: UUID = UUID(),
        title: String,
        detailsText: String,
        dueAt: Date,
        channel: TouchpointChannel,
        priority: TouchpointPriority,
        isComplete: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        clientID: UUID? = nil,
        bookingID: UUID? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        isSystemReminderEnabled: Bool = true,
        source: TouchpointSource = .manual
    ) {
        self.id = id
        self.title = title
        self.detailsText = detailsText
        self.dueAt = dueAt
        self.channel = channel
        self.priority = priority
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.clientID = clientID
        self.bookingID = bookingID
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.isSystemReminderEnabled = isSystemReminderEnabled
        self.source = source
    }

    mutating func markCompleted(on date: Date = .now) {
        isComplete = true
        completedAt = date
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detailsText
        case dueAt
        case channel
        case priority
        case isComplete
        case completedAt
        case createdAt
        case clientID
        case bookingID
        case isArchived
        case archivedAt
        case isSystemReminderEnabled
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        detailsText = try container.decodeIfPresent(String.self, forKey: .detailsText) ?? ""
        dueAt = try container.decode(Date.self, forKey: .dueAt)
        channel = try container.decodeIfPresent(TouchpointChannel.self, forKey: .channel) ?? .wechat
        priority = try container.decodeIfPresent(TouchpointPriority.self, forKey: .priority) ?? .medium
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        bookingID = try container.decodeIfPresent(UUID.self, forKey: .bookingID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        isSystemReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSystemReminderEnabled) ?? true
        source = try container.decodeIfPresent(TouchpointSource.self, forKey: .source) ?? .manual
    }
}
