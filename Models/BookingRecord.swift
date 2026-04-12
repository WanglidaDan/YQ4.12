import Foundation
import CoreLocation

struct BookingRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var category: ServiceCategory
    var status: BookingStatus
    var startAt: Date
    var endAt: Date
    var venue: String
    var city: String
    var addressText: String
    var locationNote: String
    var latitude: Double?
    var longitude: Double?
    var fee: Double
    var depositPaid: Double
    var deliverableText: String
    var notesText: String
    var shootingAttributes: [ShootingAttribute]
    var crewAssignments: [BookingCrewAssignment]
    var reminderOffsets: [BookingReminderOffset]
    var createdAt: Date
    var clientID: UUID?
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: ServiceCategory,
        status: BookingStatus,
        startAt: Date,
        endAt: Date,
        venue: String,
        city: String,
        addressText: String = "",
        locationNote: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        fee: Double,
        depositPaid: Double,
        deliverableText: String,
        notesText: String,
        shootingAttributes: [ShootingAttribute]? = nil,
        crewAssignments: [BookingCrewAssignment]? = nil,
        reminderOffsets: [BookingReminderOffset] = BookingReminderOffset.defaultSelection,
        createdAt: Date = .now,
        clientID: UUID? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.status = status
        self.startAt = startAt
        self.endAt = endAt
        self.venue = venue
        self.city = city
        self.addressText = addressText
        self.locationNote = locationNote
        self.latitude = latitude
        self.longitude = longitude
        self.fee = fee
        self.depositPaid = depositPaid
        self.deliverableText = deliverableText
        self.notesText = notesText
        self.shootingAttributes = ShootingAttribute.normalized(shootingAttributes ?? ShootingAttribute.defaultSelection(for: category))
        self.crewAssignments = BookingCrewAssignment.normalized(crewAssignments ?? [])
        self.reminderOffsets = BookingReminderOffset.normalized(reminderOffsets)
        self.createdAt = createdAt
        self.clientID = clientID
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var outstandingAmount: Double {
        max(fee - depositPaid, 0)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullAddressText: String {
        [city, venue, addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }

    var navigationQueryText: String {
        [city, venue, addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    var hasResolvedCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, category, status, startAt, endAt, venue, city, addressText, locationNote, latitude, longitude, fee, depositPaid, deliverableText, notesText, shootingAttributes, crewAssignments, reminderOffsets, createdAt, clientID, isArchived, archivedAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case shootingAttribute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(ServiceCategory.self, forKey: .category)
        status = try container.decode(BookingStatus.self, forKey: .status)
        startAt = try container.decode(Date.self, forKey: .startAt)
        endAt = try container.decode(Date.self, forKey: .endAt)
        venue = try container.decode(String.self, forKey: .venue)
        city = try container.decode(String.self, forKey: .city)
        addressText = try container.decodeIfPresent(String.self, forKey: .addressText) ?? ""
        locationNote = try container.decodeIfPresent(String.self, forKey: .locationNote) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        fee = try container.decode(Double.self, forKey: .fee)
        depositPaid = try container.decode(Double.self, forKey: .depositPaid)
        deliverableText = try container.decode(String.self, forKey: .deliverableText)
        notesText = try container.decode(String.self, forKey: .notesText)
        if let shootingAttributes = try container.decodeIfPresent([ShootingAttribute].self, forKey: .shootingAttributes) {
            self.shootingAttributes = ShootingAttribute.normalized(shootingAttributes)
        } else if let legacyRawValue = try legacyContainer.decodeIfPresent(String.self, forKey: .shootingAttribute) {
            self.shootingAttributes = ShootingAttribute.legacySelection(from: legacyRawValue)
        } else {
            self.shootingAttributes = ShootingAttribute.defaultSelection(for: category)
        }
        crewAssignments = BookingCrewAssignment.normalized(
            try container.decodeIfPresent([BookingCrewAssignment].self, forKey: .crewAssignments) ?? []
        )
        reminderOffsets = BookingReminderOffset.normalized(
            try container.decodeIfPresent([BookingReminderOffset].self, forKey: .reminderOffsets) ?? [.oneDayBefore]
        )
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}
