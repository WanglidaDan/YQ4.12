import Foundation

struct OverviewMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let symbolName: String
}

struct OverviewBookingSection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let bookings: [BookingRecord]
}

struct OverviewActionItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case followUp
        case confirmBooking
        case confirmationSheet
        case delivery
        case receivable
    }

    let id: Kind
    let title: String
    let valueText: String
    let subtitle: String
    let symbolName: String
}

struct OverviewSnapshot {
    var metrics: [OverviewMetric]
    var todayBookings: [BookingRecord]
    var nextBookings: [BookingRecord]
    var urgentTouchpoints: [TouchpointRecord]
    var bookingSections: [OverviewBookingSection]
    var pendingActions: [OverviewActionItem]
    var receivableBookings: [BookingRecord]
    var monthlyBookedCount: Int
    var monthlyRevenue: Double
    var yearlyRevenue: Double
    var monthlyReceived: Double
    var monthlyOutstanding: Double
}

struct OverviewSnapshotBuilder {
    var now: Date
    var calendar: Calendar = .current

    func build(
        clients: [ClientRecord],
        bookings: [BookingRecord],
        touchpoints: [TouchpointRecord],
        payments: [PaymentRecord]
    ) -> OverviewSnapshot {
        let activeBookings = bookings
            .filter { $0.isArchived == false }
            .sorted { $0.startAt < $1.startAt }

        let pendingTouchpoints = touchpoints
            .filter { $0.isArchived == false && $0.isComplete == false }
            .sorted { $0.dueAt < $1.dueAt }

        let startOfToday = calendar.startOfDay(for: now)
        let endOfThirdDay = calendar.date(byAdding: .day, value: 3, to: startOfToday) ?? now
        let recentWindowBookings = activeBookings.filter { $0.startAt >= startOfToday && $0.startAt < endOfThirdDay }
        let nextBookings = Array(activeBookings.filter {
            $0.startAt >= startOfToday && $0.status != .cancelled
        }.prefix(4))

        let todayBookings = recentWindowBookings.filter { calendar.isDateInToday($0.startAt) }
        let tomorrowBookings = recentWindowBookings.filter { calendar.isDateInTomorrow($0.startAt) }
        let upcomingBookings = recentWindowBookings.filter {
            calendar.isDateInToday($0.startAt) == false && calendar.isDateInTomorrow($0.startAt) == false
        }

        let bookingSections = [
            OverviewBookingSection(id: "today", title: "今天", subtitle: "优先处理今天的拍摄与沟通", bookings: todayBookings),
            OverviewBookingSection(id: "tomorrow", title: "明天", subtitle: "提前确认次日拍摄安排", bookings: tomorrowBookings),
            OverviewBookingSection(id: "nextThreeDays", title: "最近 3 天", subtitle: "把近期开工项目排进同一条时间线", bookings: upcomingBookings)
        ]
        .filter { $0.bookings.isEmpty == false }

        let urgentTouchpoints = Array(pendingTouchpoints.prefix(5))

        let receivableBookings = activeBookings
            .filter { paymentStatus(for: $0, payments: payments) != .paidInFull && $0.status != .cancelled }
            .sorted { outstandingAmount(for: $0, payments: payments) > outstandingAmount(for: $1, payments: payments) }

        let revenueBookings = activeBookings.filter { $0.status != .cancelled }
        let monthlyBookings = revenueBookings.filter {
            calendar.isDate($0.startAt, equalTo: now, toGranularity: .year) &&
            calendar.isDate($0.startAt, equalTo: now, toGranularity: .month)
        }
        let yearlyBookings = revenueBookings.filter {
            calendar.isDate($0.startAt, equalTo: now, toGranularity: .year)
        }

        let monthlyRevenue = monthlyBookings.reduce(0) { $0 + $1.fee }
        let yearlyRevenue = yearlyBookings.reduce(0) { $0 + $1.fee }
        let monthlyReceived = monthlyBookings.reduce(0) { $0 + receivedAmount(for: $1, payments: payments) }
        let monthlyOutstanding = monthlyBookings.reduce(0) { $0 + outstandingAmount(for: $1, payments: payments) }

        let pendingActions = [
            OverviewActionItem(
                id: .followUp,
                title: "待跟进客户",
                valueText: "\(pendingTouchpoints.count)",
                subtitle: "优先推进线索与拍前确认",
                symbolName: "bubble.left.and.bubble.right"
            ),
            OverviewActionItem(
                id: .confirmBooking,
                title: "待确认档期",
                valueText: "\(activeBookings.filter { $0.status == .tentative || $0.status == .inquiry }.count)",
                subtitle: "尽快锁定时间与客户意向",
                symbolName: "calendar.badge.clock"
            ),
            OverviewActionItem(
                id: .confirmationSheet,
                title: "待发送确认单",
                valueText: "\(activeBookings.filter { $0.status == .confirmed }.count)",
                subtitle: "把场地、时间和联系人发给客户",
                symbolName: "doc.badge.ellipsis"
            ),
            OverviewActionItem(
                id: .delivery,
                title: "待交付",
                valueText: "\(activeBookings.filter { $0.status == .editing }.count)",
                subtitle: "检查后期进度与交付节奏",
                symbolName: "shippingbox"
            ),
            OverviewActionItem(
                id: .receivable,
                title: "待回款",
                valueText: AppFormatters.currency(receivableBookings.reduce(0) { $0 + outstandingAmount(for: $1, payments: payments) }),
                subtitle: "本月重点跟进的回款动作",
                symbolName: "banknote"
            )
        ]

        let outstanding = receivableBookings.reduce(0) { $0 + outstandingAmount(for: $1, payments: payments) }
        let activeCount = activeBookings.filter { $0.status != .delivered && $0.status != .cancelled }.count

        let metrics = [
            OverviewMetric(
                id: "recent",
                title: "近三天档期",
                value: "\(nextBookings.count)",
                subtitle: "最近三个档期",
                symbolName: "calendar"
            ),
            OverviewMetric(
                id: "followups",
                title: "待处理事项",
                value: "\(pendingTouchpoints.count + activeBookings.filter { $0.status == .editing }.count)",
                subtitle: "跟进、交付与确认动作",
                symbolName: "checklist"
            ),
            OverviewMetric(
                id: "balance",
                title: "待回款",
                value: AppFormatters.currency(outstanding),
                subtitle: "全部未结清金额",
                symbolName: "banknote"
            ),
            OverviewMetric(
                id: "active",
                title: "活跃客户",
                value: "\(clients.filter { $0.isArchived == false }.count)",
                subtitle: "\(activeCount) 个活跃档期正在推进",
                symbolName: "person.2"
            )
        ]

        return OverviewSnapshot(
            metrics: metrics,
            todayBookings: todayBookings,
            nextBookings: nextBookings,
            urgentTouchpoints: urgentTouchpoints,
            bookingSections: bookingSections,
            pendingActions: pendingActions,
            receivableBookings: Array(receivableBookings.prefix(5)),
            monthlyBookedCount: monthlyBookings.count,
            monthlyRevenue: monthlyRevenue,
            yearlyRevenue: yearlyRevenue,
            monthlyReceived: monthlyReceived,
            monthlyOutstanding: monthlyOutstanding
        )
    }

    private func receivedAmount(for booking: BookingRecord, payments: [PaymentRecord]) -> Double {
        let records = payments.filter { $0.bookingID == booking.id }
        let refunds = records.filter { $0.paymentType == .refund }.reduce(0) { $0 + max($1.amount, 0) }
        let positive = records.filter { $0.paymentType != .refund }.reduce(0) { $0 + max($1.amount, 0) }
        return max(positive - refunds, 0)
    }

    private func outstandingAmount(for booking: BookingRecord, payments: [PaymentRecord]) -> Double {
        max(booking.fee - receivedAmount(for: booking, payments: payments), 0)
    }

    private func paymentStatus(for booking: BookingRecord, payments: [PaymentRecord]) -> PaymentStatus {
        let received = receivedAmount(for: booking, payments: payments)
        let records = payments.filter { $0.bookingID == booking.id }
        let refunds = records.filter { $0.paymentType == .refund }
        if refunds.isEmpty == false && received == 0 {
            return .refunded
        }
        if received <= 0 {
            return .unpaidDeposit
        }
        if received >= booking.fee {
            return .paidInFull
        }
        let hasBalance = records.contains { $0.paymentType == .balance && $0.amount > 0 }
        return hasBalance ? .balanceDue : .depositReceived
    }
}
