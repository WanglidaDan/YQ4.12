import Foundation

enum BookingCrewRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case leadPhoto
    case assistantPhoto
    case video
    case live
    case edit
    case color
    case coordinator
    case support
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leadPhoto: "主拍"
        case .assistantPhoto: "副拍"
        case .video: "摄像"
        case .live: "直播"
        case .edit: "剪辑"
        case .color: "调色"
        case .coordinator: "统筹"
        case .support: "跟场"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .leadPhoto: "camera.fill"
        case .assistantPhoto: "person.2.fill"
        case .video: "video.fill"
        case .live: "antenna.radiowaves.left.and.right"
        case .edit: "scissors"
        case .color: "paintbrush.pointed.fill"
        case .coordinator: "checklist"
        case .support: "location.fill"
        case .other: "ellipsis.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .leadPhoto: 0
        case .assistantPhoto: 1
        case .video: 2
        case .live: 3
        case .coordinator: 4
        case .support: 5
        case .edit: 6
        case .color: 7
        case .other: 8
        }
    }
}

struct BookingCrewAssignment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var memberName: String
    var role: BookingCrewRole
    var taskText: String
    var venueText: String
    var notesText: String

    init(
        id: UUID = UUID(),
        memberName: String,
        role: BookingCrewRole,
        taskText: String = "",
        venueText: String = "",
        notesText: String = ""
    ) {
        self.id = id
        self.memberName = memberName
        self.role = role
        self.taskText = taskText
        self.venueText = venueText
        self.notesText = notesText
    }

    var summaryText: String {
        [taskText, venueText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }

    var displayName: String {
        let trimmed = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名成员" : trimmed
    }

    var headlineText: String {
        "\(displayName) · \(role.title)"
    }

    var locationSummaryText: String {
        let trimmed = venueText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待确认去向" : trimmed
    }

    var operationalSummaryText: String {
        let task = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = venueText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (task.isEmpty, location.isEmpty) {
        case (false, false):
            return "\(task) · \(location)"
        case (false, true):
            return task
        case (true, false):
            return location
        case (true, true):
            return role.title
        }
    }

    var noteSummaryText: String? {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func matches(memberName: String) -> Bool {
        let normalizedInput = Self.normalizedMemberKey(memberName)
        guard normalizedInput.isEmpty == false else { return false }
        return Self.normalizedMemberKey(displayName) == normalizedInput
    }

    static func normalized(_ assignments: [BookingCrewAssignment]) -> [BookingCrewAssignment] {
        assignments
            .map { assignment in
                var normalized = assignment
                normalized.memberName = assignment.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.taskText = assignment.taskText.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.venueText = assignment.venueText.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.notesText = assignment.notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized
            }
            .filter { $0.memberName.isEmpty == false || $0.taskText.isEmpty == false || $0.venueText.isEmpty == false || $0.notesText.isEmpty == false }
            .sorted {
                if $0.role.sortOrder != $1.role.sortOrder {
                    return $0.role.sortOrder < $1.role.sortOrder
                }
                return $0.memberName.localizedStandardCompare($1.memberName) == .orderedAscending
            }
    }

    private static func normalizedMemberKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
