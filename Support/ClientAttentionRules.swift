import Foundation

enum ClientAttentionRules {
    static func needsAttention(
        client: ClientRecord,
        nextPendingTouchpoint: TouchpointRecord?,
        outstandingValue: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let nextDue = nextPendingTouchpoint?.dueAt ?? client.nextContactAt
        let isOverdue = nextDue.map { $0 < now && calendar.isDateInToday($0) == false } ?? false
        return isOverdue || outstandingValue > 0
    }
}
