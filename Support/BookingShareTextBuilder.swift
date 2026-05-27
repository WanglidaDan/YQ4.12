import Foundation

enum BookingShareTextBuilder {
    static func crewAssignmentSummary(for booking: BookingRecord) -> String {
        let assignments = BookingCrewAssignment.normalized(booking.crewAssignments)
        guard assignments.isEmpty == false else { return "" }

        return assignments
            .map { assignment in
                let detail = assignment.operationalSummaryText.trimmingCharacters(in: .whitespacesAndNewlines)
                if detail.isEmpty || detail == assignment.role.title {
                    return "\(assignment.role.title)：\(assignment.displayName)"
                }
                return "\(assignment.role.title)：\(assignment.displayName) · \(detail)"
            }
            .joined(separator: " / ")
    }
}
