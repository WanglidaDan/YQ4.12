import Foundation

struct StudioStoreSnapshot: Codable, Sendable {
    var version: Int
    var clients: [ClientRecord]
    var documents: [BusinessDocumentRecord]
    var attachments: [AttachmentRecord]
    var calendarLinks: [CalendarSyncLinkRecord]
    var workspaceMembers: [WorkspaceMemberRecord]
    var collaborationSettings: WorkspaceCollaborationSettings
    var collaborationActivities: [CollaborationActivityRecord]
    var googleCalendarConnection: GoogleCalendarConnection
    var bookings: [BookingRecord]
    var touchpoints: [TouchpointRecord]
    var payments: [PaymentRecord]
    var crewMembers: [CrewMemberRecord]
    var studioProfile: StudioProfile
    var templates: [BookingTemplate]
    var settings: AppSettings
    var authProfile: AuthProfile?
    var workspaceOwnerAppleUserID: String?
    var lastModifiedAt: Date

    static let currentVersion = 5

    static let empty = StudioStoreSnapshot(
        version: currentVersion,
        clients: [],
        documents: [],
        attachments: [],
        calendarLinks: [],
        workspaceMembers: [],
        collaborationSettings: .default,
        collaborationActivities: [],
        googleCalendarConnection: .empty,
        bookings: [],
        touchpoints: [],
        payments: [],
        crewMembers: [],
        studioProfile: .empty,
        templates: [],
        settings: .default,
        authProfile: nil,
        workspaceOwnerAppleUserID: nil,
        lastModifiedAt: .now
    )

    private enum CodingKeys: String, CodingKey {
        case version
        case clients
        case documents
        case attachments
        case calendarLinks
        case workspaceMembers
        case collaborationSettings
        case collaborationActivities
        case googleCalendarConnection
        case bookings
        case touchpoints
        case payments
        case crewMembers
        case studioProfile
        case templates
        case settings
        case authProfile
        case workspaceOwnerAppleUserID
        case lastModifiedAt
    }

    init(
        version: Int = currentVersion,
        clients: [ClientRecord],
        documents: [BusinessDocumentRecord] = [],
        attachments: [AttachmentRecord] = [],
        calendarLinks: [CalendarSyncLinkRecord] = [],
        workspaceMembers: [WorkspaceMemberRecord] = [],
        collaborationSettings: WorkspaceCollaborationSettings = .default,
        collaborationActivities: [CollaborationActivityRecord] = [],
        googleCalendarConnection: GoogleCalendarConnection = .empty,
        bookings: [BookingRecord],
        touchpoints: [TouchpointRecord],
        payments: [PaymentRecord] = [],
        crewMembers: [CrewMemberRecord] = [],
        studioProfile: StudioProfile = .empty,
        templates: [BookingTemplate] = [],
        settings: AppSettings = .default,
        authProfile: AuthProfile? = nil,
        workspaceOwnerAppleUserID: String? = nil,
        lastModifiedAt: Date = .now
    ) {
        self.version = version
        self.clients = clients
        self.documents = documents
        self.attachments = attachments
        self.calendarLinks = calendarLinks
        self.workspaceMembers = workspaceMembers
        self.collaborationSettings = collaborationSettings
        self.collaborationActivities = collaborationActivities
        self.googleCalendarConnection = googleCalendarConnection
        self.bookings = bookings
        self.touchpoints = touchpoints
        self.payments = payments
        self.crewMembers = crewMembers
        self.studioProfile = studioProfile
        self.templates = templates
        self.settings = settings
        self.authProfile = authProfile
        self.workspaceOwnerAppleUserID = workspaceOwnerAppleUserID
        self.lastModifiedAt = lastModifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        clients = try container.decodeIfPresent([ClientRecord].self, forKey: .clients) ?? []
        documents = try container.decodeIfPresent([BusinessDocumentRecord].self, forKey: .documents) ?? []
        attachments = try container.decodeIfPresent([AttachmentRecord].self, forKey: .attachments) ?? []
        calendarLinks = try container.decodeIfPresent([CalendarSyncLinkRecord].self, forKey: .calendarLinks) ?? []
        workspaceMembers = try container.decodeIfPresent([WorkspaceMemberRecord].self, forKey: .workspaceMembers) ?? []
        collaborationSettings = try container.decodeIfPresent(WorkspaceCollaborationSettings.self, forKey: .collaborationSettings) ?? .default
        collaborationActivities = try container.decodeIfPresent([CollaborationActivityRecord].self, forKey: .collaborationActivities) ?? []
        googleCalendarConnection = try container.decodeIfPresent(GoogleCalendarConnection.self, forKey: .googleCalendarConnection) ?? .empty
        bookings = try container.decodeIfPresent([BookingRecord].self, forKey: .bookings) ?? []
        touchpoints = try container.decodeIfPresent([TouchpointRecord].self, forKey: .touchpoints) ?? []
        payments = try container.decodeIfPresent([PaymentRecord].self, forKey: .payments) ?? []
        crewMembers = try container.decodeIfPresent([CrewMemberRecord].self, forKey: .crewMembers) ?? []
        studioProfile = try container.decodeIfPresent(StudioProfile.self, forKey: .studioProfile) ?? .empty
        templates = try container.decodeIfPresent([BookingTemplate].self, forKey: .templates) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? .default
        authProfile = try container.decodeIfPresent(AuthProfile.self, forKey: .authProfile)
        workspaceOwnerAppleUserID = try container.decodeIfPresent(String.self, forKey: .workspaceOwnerAppleUserID)
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? .now
    }
}
