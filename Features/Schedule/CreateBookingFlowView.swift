import SwiftUI

/// Carries the entry-point intent into the booking creation flow so a new schedule
/// can be prefilled from the current screen instead of opening a blank database-style form.
struct CreateBookingContext: Hashable {
    enum Source: Hashable {
        case overview
        case schedule
        case clientDetail
        case team
        case quickAction
    }

    var source: Source
    var defaultDate: Date?
    var defaultClientID: UUID?
    var defaultCrewMemberName: String?
    var defaultCategory: ServiceCategory?
    var defaultTitle: String?

    static let overview = CreateBookingContext(source: .overview)

    static func schedule(focusDate: Date, crewMemberName: String? = nil) -> CreateBookingContext {
        CreateBookingContext(
            source: .schedule,
            defaultDate: focusDate,
            defaultCrewMemberName: crewMemberName
        )
    }

    static func clientDetail(clientID: UUID) -> CreateBookingContext {
        CreateBookingContext(source: .clientDetail, defaultClientID: clientID)
    }
}

/// A lightweight creation shell that makes the creation intent explicit.
///
/// The existing `BookingEditorView` still owns the final save logic so this change is
/// low-risk. The shell introduces a clean product boundary for the next step: replacing
/// the single large editor form with a true step-by-step quick-create flow.
struct CreateBookingFlowView: View {
    @Environment(StudioStore.self) private var store

    let context: CreateBookingContext

    init(context: CreateBookingContext = .overview) {
        self.context = context
    }

    var body: some View {
        BookingEditorView(booking: draftBooking)
            .environment(store)
    }

    private var draftBooking: BookingRecord? {
        guard context.defaultDate != nil ||
              context.defaultClientID != nil ||
              context.defaultCrewMemberName != nil ||
              context.defaultCategory != nil ||
              context.defaultTitle != nil else {
            return nil
        }

        let start = normalizedStartDate(from: context.defaultDate ?? .now.addingTimeInterval(86_400))
        let end = Calendar.current.date(byAdding: .hour, value: 4, to: start) ?? start.addingTimeInterval(14_400)
        let category = context.defaultCategory ?? .wedding
        let trimmedTitle = context.defaultTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let crew = context.defaultCrewMemberName
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .map { [BookingCrewAssignment(memberName: $0, role: .leadPhoto)] } ?? []

        return BookingRecord(
            id: UUID(),
            title: trimmedTitle.isEmpty ? defaultTitle(for: category) : trimmedTitle,
            category: category,
            status: .inquiry,
            startAt: start,
            endAt: end,
            venue: store.settings.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            city: "",
            addressText: "",
            locationNote: "",
            latitude: nil,
            longitude: nil,
            fee: 0,
            depositPaid: 0,
            deliverableText: "",
            notesText: store.settings.defaultNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: ShootingAttribute.defaultSelection(for: category),
            crewAssignments: crew,
            reminderOffsets: BookingReminderOffset.defaultSelection,
            createdAt: .now,
            clientID: context.defaultClientID
        )
    }

    private func normalizedStartDate(from date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if components.hour == 0 && components.minute == 0 {
            components.hour = 9
            components.minute = 0
        }
        return calendar.date(from: components) ?? date
    }

    private func defaultTitle(for category: ServiceCategory) -> String {
        switch context.source {
        case .overview, .quickAction:
            return "新拍摄档期"
        case .schedule:
            return "当天拍摄档期"
        case .clientDetail:
            return "客户拍摄档期"
        case .team:
            return "团队拍摄档期"
        }
    }
}
