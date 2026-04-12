import Foundation

enum BusinessDocumentKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case quote
    case contract
    case receipt
    case invoice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quote: "报价单"
        case .contract: "合同"
        case .receipt: "收据"
        case .invoice: "发票"
        }
    }

    var prefix: String {
        switch self {
        case .quote: "QUO"
        case .contract: "CON"
        case .receipt: "REC"
        case .invoice: "INV"
        }
    }

    var symbolName: String {
        switch self {
        case .quote: "doc.text.magnifyingglass"
        case .contract: "doc.text.fill"
        case .receipt: "checkmark.seal.text.page.fill"
        case .invoice: "doc.richtext.fill"
        }
    }

    var suggestedNextKind: BusinessDocumentKind? {
        switch self {
        case .quote: .contract
        case .contract: .receipt
        case .receipt: .invoice
        case .invoice: nil
        }
    }
}

enum BusinessDocumentStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case draft
    case sent
    case approved
    case signed
    case issued
    case paid
    case voided

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "草稿"
        case .sent: "已发送"
        case .approved: "已确认"
        case .signed: "已签署"
        case .issued: "已开具"
        case .paid: "已完成"
        case .voided: "已作废"
        }
    }
}

struct BusinessDocumentLineItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var detailsText: String
    var quantity: Double
    var unitPrice: Double

    init(id: UUID = UUID(), title: String, detailsText: String = "", quantity: Double = 1, unitPrice: Double) {
        self.id = id
        self.title = title
        self.detailsText = detailsText
        self.quantity = quantity
        self.unitPrice = unitPrice
    }

    var lineTotal: Double {
        max(quantity, 0) * max(unitPrice, 0)
    }
}

struct BusinessDocumentRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var bookingID: UUID?
    var clientID: UUID?
    var kind: BusinessDocumentKind
    var status: BusinessDocumentStatus
    var number: String
    var title: String
    var recipientName: String
    var issueDate: Date
    var dueDate: Date?
    var lineItems: [BusinessDocumentLineItem]
    var discountAmount: Double
    var taxRate: Double
    var notesText: String
    var termsText: String
    var linkedDocumentID: UUID?
    var linkedPaymentIDs: [UUID]
    var linkedAttachmentIDs: [UUID]
    var lastSharedAt: Date?
    var signedAt: Date?
    var paidAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        bookingID: UUID? = nil,
        clientID: UUID? = nil,
        kind: BusinessDocumentKind,
        status: BusinessDocumentStatus = .draft,
        number: String,
        title: String,
        recipientName: String = "",
        issueDate: Date = .now,
        dueDate: Date? = nil,
        lineItems: [BusinessDocumentLineItem] = [],
        discountAmount: Double = 0,
        taxRate: Double = 0,
        notesText: String = "",
        termsText: String = "",
        linkedDocumentID: UUID? = nil,
        linkedPaymentIDs: [UUID] = [],
        linkedAttachmentIDs: [UUID] = [],
        lastSharedAt: Date? = nil,
        signedAt: Date? = nil,
        paidAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.bookingID = bookingID
        self.clientID = clientID
        self.kind = kind
        self.status = status
        self.number = number
        self.title = title
        self.recipientName = recipientName
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.lineItems = lineItems
        self.discountAmount = discountAmount
        self.taxRate = taxRate
        self.notesText = notesText
        self.termsText = termsText
        self.linkedDocumentID = linkedDocumentID
        self.linkedPaymentIDs = linkedPaymentIDs
        self.linkedAttachmentIDs = linkedAttachmentIDs
        self.lastSharedAt = lastSharedAt
        self.signedAt = signedAt
        self.paidAt = paidAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var subtotalAmount: Double {
        lineItems.reduce(0) { $0 + $1.lineTotal }
    }

    var taxableBaseAmount: Double {
        max(subtotalAmount - max(discountAmount, 0), 0)
    }

    var taxAmount: Double {
        taxableBaseAmount * max(taxRate, 0)
    }

    var totalAmount: Double {
        taxableBaseAmount + taxAmount
    }

    var lifecycleHeadline: String {
        switch kind {
        case .quote:
            switch status {
            case .draft: "报价待发送"
            case .sent: "等待客户确认报价"
            case .approved, .signed, .issued, .paid: "报价已确认，可进入签约"
            case .voided: "报价已作废"
            }
        case .contract:
            switch status {
            case .draft: "合同待完善"
            case .sent: "合同待发送"
            case .approved, .signed: "合同已进入签署阶段"
            case .issued, .paid: "合同已生效"
            case .voided: "合同已作废"
            }
        case .receipt:
            switch status {
            case .draft: "收据待开具"
            case .sent, .issued: "收据已开具"
            case .approved, .signed, .paid: "收据已确认"
            case .voided: "收据已作废"
            }
        case .invoice:
            switch status {
            case .draft: "发票待开具"
            case .sent, .issued: "发票已开具"
            case .approved, .signed, .paid: "发票已处理"
            case .voided: "发票已作废"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookingID
        case clientID
        case kind
        case status
        case number
        case title
        case recipientName
        case issueDate
        case dueDate
        case lineItems
        case discountAmount
        case taxRate
        case notesText
        case termsText
        case linkedDocumentID
        case linkedPaymentIDs
        case linkedAttachmentIDs
        case lastSharedAt
        case signedAt
        case paidAt
        case createdAt
        case updatedAt
        case isArchived
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bookingID = try container.decodeIfPresent(UUID.self, forKey: .bookingID)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        kind = try container.decodeIfPresent(BusinessDocumentKind.self, forKey: .kind) ?? .quote
        status = try container.decodeIfPresent(BusinessDocumentStatus.self, forKey: .status) ?? .draft
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? kind.title
        recipientName = try container.decodeIfPresent(String.self, forKey: .recipientName) ?? ""
        issueDate = try container.decodeIfPresent(Date.self, forKey: .issueDate) ?? .now
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        lineItems = try container.decodeIfPresent([BusinessDocumentLineItem].self, forKey: .lineItems) ?? []
        discountAmount = try container.decodeIfPresent(Double.self, forKey: .discountAmount) ?? 0
        taxRate = try container.decodeIfPresent(Double.self, forKey: .taxRate) ?? 0
        notesText = try container.decodeIfPresent(String.self, forKey: .notesText) ?? ""
        termsText = try container.decodeIfPresent(String.self, forKey: .termsText) ?? ""
        linkedDocumentID = try container.decodeIfPresent(UUID.self, forKey: .linkedDocumentID)
        linkedPaymentIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedPaymentIDs) ?? []
        linkedAttachmentIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedAttachmentIDs) ?? []
        lastSharedAt = try container.decodeIfPresent(Date.self, forKey: .lastSharedAt)
        signedAt = try container.decodeIfPresent(Date.self, forKey: .signedAt)
        paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

enum AttachmentCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case reference
    case moodboard
    case shotList
    case contract
    case quote
    case receipt
    case invoice
    case permit
    case location
    case communication
    case deliverable
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reference: "参考资料"
        case .moodboard: "风格板"
        case .shotList: "镜头清单"
        case .contract: "合同附件"
        case .quote: "报价附件"
        case .receipt: "收据附件"
        case .invoice: "发票附件"
        case .permit: "授权 / 许可"
        case .location: "场地资料"
        case .communication: "沟通记录"
        case .deliverable: "交付素材"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .reference: "sparkles.tv"
        case .moodboard: "rectangle.stack.person.crop"
        case .shotList: "checklist"
        case .contract: "doc.text.fill"
        case .quote: "doc.text.magnifyingglass"
        case .receipt: "checkmark.seal.text.page.fill"
        case .invoice: "doc.richtext.fill"
        case .permit: "checkmark.shield.fill"
        case .location: "mappin.and.ellipse"
        case .communication: "message.fill"
        case .deliverable: "shippingbox.fill"
        case .other: "paperclip"
        }
    }
}

struct AttachmentRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var bookingID: UUID?
    var clientID: UUID?
    var documentID: UUID?
    var category: AttachmentCategory
    var title: String
    var note: String
    var tags: [String]
    var localRelativePath: String?
    var externalURLString: String
    var mimeType: String
    var byteCount: Int64
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        bookingID: UUID? = nil,
        clientID: UUID? = nil,
        documentID: UUID? = nil,
        category: AttachmentCategory,
        title: String,
        note: String = "",
        tags: [String] = [],
        localRelativePath: String? = nil,
        externalURLString: String = "",
        mimeType: String = "application/octet-stream",
        byteCount: Int64 = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.bookingID = bookingID
        self.clientID = clientID
        self.documentID = documentID
        self.category = category
        self.title = title
        self.note = note
        self.tags = tags
        self.localRelativePath = localRelativePath
        self.externalURLString = externalURLString
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var isExternalLink: Bool {
        externalURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var isLocalFile: Bool {
        localRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var preferredOpenURL: URL? {
        if let url = URL(string: externalURLString.trimmingCharacters(in: .whitespacesAndNewlines)), isExternalLink {
            return url
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookingID
        case clientID
        case documentID
        case category
        case title
        case note
        case tags
        case localRelativePath
        case externalURLString
        case mimeType
        case byteCount
        case createdAt
        case updatedAt
        case isArchived
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bookingID = try container.decodeIfPresent(UUID.self, forKey: .bookingID)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        documentID = try container.decodeIfPresent(UUID.self, forKey: .documentID)
        category = try container.decodeIfPresent(AttachmentCategory.self, forKey: .category) ?? .reference
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名资料"
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        localRelativePath = try container.decodeIfPresent(String.self, forKey: .localRelativePath)
        externalURLString = try container.decodeIfPresent(String.self, forKey: .externalURLString) ?? ""
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? "application/octet-stream"
        byteCount = try container.decodeIfPresent(Int64.self, forKey: .byteCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

enum CalendarSyncProvider: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case system
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统日历"
        case .google: "Google Calendar"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "calendar"
        case .google: "globe"
        }
    }
}

enum CalendarSyncDirection: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case twoWay
    case exportOnly
    case importOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoWay: "双向同步"
        case .exportOnly: "仅推送"
        case .importOnly: "仅回写"
        }
    }
}

enum CalendarSyncStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case pending
    case synced
    case conflict
    case disabled
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "待同步"
        case .synced: "已同步"
        case .conflict: "有冲突"
        case .disabled: "未启用"
        case .error: "异常"
        }
    }
}

struct CalendarSyncLinkRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var bookingID: UUID
    var provider: CalendarSyncProvider
    var externalCalendarID: String
    var externalEventID: String
    var direction: CalendarSyncDirection
    var status: CalendarSyncStatus
    var lastSyncedAt: Date?
    var lastExternalModifiedAt: Date?
    var lastKnownExternalStartAt: Date?
    var lastKnownExternalEndAt: Date?
    var remotePayloadDigest: String
    var notesText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookingID: UUID,
        provider: CalendarSyncProvider,
        externalCalendarID: String,
        externalEventID: String,
        direction: CalendarSyncDirection = .twoWay,
        status: CalendarSyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        lastExternalModifiedAt: Date? = nil,
        lastKnownExternalStartAt: Date? = nil,
        lastKnownExternalEndAt: Date? = nil,
        remotePayloadDigest: String = "",
        notesText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookingID = bookingID
        self.provider = provider
        self.externalCalendarID = externalCalendarID
        self.externalEventID = externalEventID
        self.direction = direction
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.lastExternalModifiedAt = lastExternalModifiedAt
        self.lastKnownExternalStartAt = lastKnownExternalStartAt
        self.lastKnownExternalEndAt = lastKnownExternalEndAt
        self.remotePayloadDigest = remotePayloadDigest
        self.notesText = notesText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct GoogleCalendarConnection: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var accountEmail: String
    var calendarID: String
    var oauthClientID: String
    var oauthClientSecret: String
    var accessToken: String
    var refreshToken: String
    var tokenExpiryAt: Date?
    var syncDirection: CalendarSyncDirection
    var autoCreateMissingEvents: Bool
    var writeBookingAddressToLocation: Bool

    static let empty = GoogleCalendarConnection(
        isEnabled: false,
        accountEmail: "",
        calendarID: "primary",
        oauthClientID: "",
        oauthClientSecret: "",
        accessToken: "",
        refreshToken: "",
        tokenExpiryAt: nil,
        syncDirection: .twoWay,
        autoCreateMissingEvents: true,
        writeBookingAddressToLocation: true
    )

    var isConfigured: Bool {
        isEnabled && accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && calendarID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var redactedForPersistence: GoogleCalendarConnection {
        var copy = self
        copy.oauthClientSecret = ""
        copy.accessToken = ""
        copy.refreshToken = ""
        copy.tokenExpiryAt = nil
        return copy
    }
}

enum WorkspacePermission: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case manageClients
    case manageBookings
    case manageFollowUps
    case managePayments
    case manageDocuments
    case manageAttachments
    case manageCalendarSync
    case manageWorkspace
    case viewAnalytics
    case exportData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manageClients: "客户管理"
        case .manageBookings: "档期管理"
        case .manageFollowUps: "跟进管理"
        case .managePayments: "回款管理"
        case .manageDocuments: "合同 / 报价 / 票据"
        case .manageAttachments: "附件资料"
        case .manageCalendarSync: "日历同步"
        case .manageWorkspace: "团队与权限"
        case .viewAnalytics: "经营报表"
        case .exportData: "导出与备份"
        }
    }
}

enum WorkspaceRole: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case owner
    case admin
    case producer
    case photographer
    case finance
    case viewer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "所有者"
        case .admin: "管理员"
        case .producer: "制片 / 统筹"
        case .photographer: "摄影师"
        case .finance: "财务"
        case .viewer: "只读"
        }
    }

    var permissions: Set<WorkspacePermission> {
        switch self {
        case .owner, .admin:
            Set(WorkspacePermission.allCases)
        case .producer:
            [.manageClients, .manageBookings, .manageFollowUps, .manageDocuments, .manageAttachments, .manageCalendarSync, .viewAnalytics, .exportData]
        case .photographer:
            [.manageBookings, .manageFollowUps, .manageAttachments, .manageCalendarSync, .viewAnalytics]
        case .finance:
            [.managePayments, .manageDocuments, .viewAnalytics, .exportData]
        case .viewer:
            [.viewAnalytics]
        }
    }
}

enum WorkspaceMemberStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case owner
    case active
    case invited
    case suspended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "工作区所有者"
        case .active: "协作中"
        case .invited: "待加入"
        case .suspended: "已暂停"
        }
    }
}

struct WorkspaceMemberRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var appleUserID: String?
    var displayName: String
    var email: String
    var role: WorkspaceRole
    var status: WorkspaceMemberStatus
    var notesText: String
    var createdAt: Date
    var lastSeenAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        appleUserID: String? = nil,
        displayName: String,
        email: String = "",
        role: WorkspaceRole,
        status: WorkspaceMemberStatus = .invited,
        notesText: String = "",
        createdAt: Date = .now,
        lastSeenAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.role = role
        self.status = status
        self.notesText = notesText
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.isActive = isActive
    }
}

struct WorkspaceCollaborationSettings: Codable, Hashable, Sendable {
    var realtimeSyncEnabled: Bool
    var showPresenceBoard: Bool
    var requireFinancialApproval: Bool
    var allowAttachmentUploadByPhotographers: Bool
    var allowViewerExport: Bool

    static let `default` = WorkspaceCollaborationSettings(
        realtimeSyncEnabled: false,
        showPresenceBoard: true,
        requireFinancialApproval: true,
        allowAttachmentUploadByPhotographers: true,
        allowViewerExport: false
    )
}

enum CollaborationActivityTarget: String, Codable, Hashable, Sendable {
    case client
    case booking
    case touchpoint
    case payment
    case document
    case attachment
    case workspace
    case calendarSync
}

struct CollaborationActivityRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var actorMemberID: UUID?
    var actorDisplayName: String
    var actionTitle: String
    var target: CollaborationActivityTarget
    var targetID: String
    var summary: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        actorMemberID: UUID? = nil,
        actorDisplayName: String,
        actionTitle: String,
        target: CollaborationActivityTarget,
        targetID: String,
        summary: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.actorMemberID = actorMemberID
        self.actorDisplayName = actorDisplayName
        self.actionTitle = actionTitle
        self.target = target
        self.targetID = targetID
        self.summary = summary
        self.createdAt = createdAt
    }
}

struct BusinessAnalyticsRevenuePoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    var monthStart: Date
    var bookedAmount: Double
    var collectedAmount: Double
}

struct BusinessAnalyticsCategoryPoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    var category: ServiceCategory
    var bookingCount: Int
    var bookedAmount: Double
}

struct BusinessAnalyticsSourcePoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    var sourceChannel: String
    var clientCount: Int
    var bookedAmount: Double
}

struct BusinessAnalyticsAgingBucket: Identifiable, Hashable, Sendable {
    let id = UUID()
    var title: String
    var amount: Double
    var bookingCount: Int
}

struct BusinessAnalyticsDashboard: Hashable, Sendable {
    var totalBookedAmount: Double
    var totalCollectedAmount: Double
    var totalOutstandingAmount: Double
    var averageTicketAmount: Double
    var repeatClientRate: Double
    var retentionClientCount: Int
    var revenueTrend: [BusinessAnalyticsRevenuePoint]
    var categoryBreakdown: [BusinessAnalyticsCategoryPoint]
    var sourceBreakdown: [BusinessAnalyticsSourcePoint]
    var agingBuckets: [BusinessAnalyticsAgingBucket]

    static let empty = BusinessAnalyticsDashboard(
        totalBookedAmount: 0,
        totalCollectedAmount: 0,
        totalOutstandingAmount: 0,
        averageTicketAmount: 0,
        repeatClientRate: 0,
        retentionClientCount: 0,
        revenueTrend: [],
        categoryBreakdown: [],
        sourceBreakdown: [],
        agingBuckets: []
    )
}
