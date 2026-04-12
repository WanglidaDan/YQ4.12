import Foundation

enum LeadStageMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case manual
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "手动维护"
        case .automatic: "自动推断"
        }
    }

    var descriptionText: String {
        switch self {
        case .manual:
            "阶段完全以你手动选择为准，不会被订单状态自动覆盖。"
        case .automatic:
            "阶段会根据已绑定订单的状态自动推断，更适合轻量 CRM。"
        }
    }
}

struct ClientRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var city: String
    var phoneNumber: String
    var wechatID: String
    var emailAddress: String
    var sourceChannel: String
    var notesText: String
    var tags: [String]
    var stage: LeadStage
    var stageMode: LeadStageMode
    var tier: ClientTier
    var createdAt: Date
    var lastContactAt: Date?
    var nextContactAt: Date?
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        city: String,
        phoneNumber: String,
        wechatID: String = "",
        emailAddress: String = "",
        sourceChannel: String,
        notesText: String,
        tags: [String] = [],
        stage: LeadStage,
        stageMode: LeadStageMode = .manual,
        tier: ClientTier,
        createdAt: Date = .now,
        lastContactAt: Date? = nil,
        nextContactAt: Date? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.phoneNumber = phoneNumber
        self.wechatID = wechatID
        self.emailAddress = emailAddress
        self.sourceChannel = sourceChannel
        self.notesText = notesText
        self.tags = tags
        self.stage = stage
        self.stageMode = stageMode
        self.tier = tier
        self.createdAt = createdAt
        self.lastContactAt = lastContactAt
        self.nextContactAt = nextContactAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var initials: String {
        let filtered = name.filter { $0.isLetter || $0.isNumber }
        if filtered.count >= 2 {
            return String(filtered.prefix(2))
        }
        return filtered.isEmpty ? "影期" : filtered
    }

    func lifetimeValue(in bookings: [BookingRecord]) -> Double {
        bookings.reduce(0) { $0 + $1.fee }
    }

    func outstandingValue(in bookings: [BookingRecord]) -> Double {
        bookings.reduce(0) { $0 + max($1.fee - $1.depositPaid, 0) }
    }

    var preferredContactText: String {
        let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if phone.isEmpty == false { return phone }
        let wechat = wechatID.trimmingCharacters(in: .whitespacesAndNewlines)
        if wechat.isEmpty == false { return "微信：\(wechat)" }
        let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty == false { return email }
        return "暂无联系方式"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case phoneNumber
        case wechatID
        case emailAddress
        case sourceChannel
        case notesText
        case tags
        case stage
        case stageMode
        case tier
        case createdAt
        case lastContactAt
        case nextContactAt
        case isArchived
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        city = try container.decode(String.self, forKey: .city)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        wechatID = try container.decodeIfPresent(String.self, forKey: .wechatID) ?? ""
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress) ?? ""
        sourceChannel = try container.decodeIfPresent(String.self, forKey: .sourceChannel) ?? ""
        notesText = try container.decodeIfPresent(String.self, forKey: .notesText) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        stage = try container.decodeIfPresent(LeadStage.self, forKey: .stage) ?? .discovery
        stageMode = try container.decodeIfPresent(LeadStageMode.self, forKey: .stageMode) ?? .automatic
        tier = try container.decodeIfPresent(ClientTier.self, forKey: .tier) ?? .standard
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        lastContactAt = try container.decodeIfPresent(Date.self, forKey: .lastContactAt)
        nextContactAt = try container.decodeIfPresent(Date.self, forKey: .nextContactAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}
