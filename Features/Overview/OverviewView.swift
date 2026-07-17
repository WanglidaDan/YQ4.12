import Foundation
import SwiftUI

struct OverviewView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.openURL) private var openURL

    let onOpenSchedule: () -> Void

    @State private var showingNewBooking = false
    @State private var editingBooking: BookingRecord?

    private var snapshot: OverviewSnapshot {
        store.overviewSnapshot
    }

    private var featuredBooking: BookingRecord? {
        snapshot.nextBookings.first
    }

    private var followingBookings: [BookingRecord] {
        Array(snapshot.nextBookings.dropFirst().prefix(3))
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "工作台", topPadding: 10, bottomPadding: 34) {
                heroCard

                if followingBookings.isEmpty == false {
                    upcomingSection
                }

                revenueSection
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建档期", systemImage: "plus", action: createBooking)
                }
            }
            .sheet(isPresented: $showingNewBooking) {
                BookingEditorView()
                    .environment(store)
            }
            .sheet(item: $editingBooking) { booking in
                BookingEditorView(booking: booking)
                    .environment(store)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let booking = featuredBooking {
                featuredBookingHeader(booking)

                Divider()
                    .overlay(.white.opacity(0.18))

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 13) {
                    heroDetailRow(
                        title: "时间",
                        systemImage: "clock",
                        value: "\(AppFormatters.shortMonthDay(booking.startAt))  \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))"
                    )
                    heroDetailRow(
                        title: "拍摄",
                        systemImage: ShootingAttribute.displaySymbolName(for: booking.shootingAttributes),
                        value: shootingBrief(for: booking)
                    )
                    heroDetailRow(
                        title: "执行",
                        systemImage: "person.2.fill",
                        value: crewSummary(for: booking)
                    )
                    heroDetailRow(
                        title: "地点",
                        systemImage: "mappin.and.ellipse",
                        value: locationDisplayText(for: booking)
                    )
                }

                navigationButton(for: booking)
            } else {
                emptyHeroContent
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.18), radius: 22, y: 12)
    }

    private func featuredBookingHeader(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("下一场")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.70))

                Spacer(minLength: 12)

                Text(relativeCountdown(for: booking))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Text(store.clientName(for: booking))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroDetailRow(title: String, systemImage: String, value: String) -> some View {
        GridRow {
            Label(title, systemImage: systemImage)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.64))
                .gridColumnAlignment(.leading)

            Text(value)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .gridColumnAlignment(.leading)
        }
    }

    private func navigationButton(for booking: BookingRecord) -> some View {
        let canNavigate = navigationDestination(for: booking) != nil

        return Button {
            if canNavigate {
                openNavigation(for: booking)
            } else {
                editingBooking = booking
                AppHaptics.tapLight()
            }
        } label: {
            Label(
                canNavigate ? "导航到拍摄地点" : "补充拍摄地点",
                systemImage: canNavigate ? "arrow.triangle.turn.up.right.diamond.fill" : "mappin.and.ellipse"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(canNavigate ? "在地图中打开驾车路线" : "打开当前订单并补充地址")
    }

    private var emptyHeroContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("下一场")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.70))

            Text("暂无待拍档期")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Button("新建档期", systemImage: "plus", action: createBooking)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .buttonStyle(.plain)
        }
    }

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.hero)
                .fill(AppTheme.heroGradient)

            LinearGradient(
                colors: [.white.opacity(0.10), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))

            RoundedRectangle(cornerRadius: AppRadius.hero)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("后续档期")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Button("查看全部", action: onOpenSchedule)
                    .font(.subheadline)
            }
            .padding(.bottom, 6)

            ForEach(Array(followingBookings.enumerated()), id: \.element.id) { item in
                upcomingBookingRow(item.element)

                if item.offset < followingBookings.count - 1 {
                    Divider()
                        .padding(.leading, 70)
                }
            }
        }
    }

    private func upcomingBookingRow(_ booking: BookingRecord) -> some View {
        Button {
            onOpenSchedule()
            AppHaptics.tapLight()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppFormatters.shortMonthDay(booking.startAt))
                        .font(.callout.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text(AppFormatters.time(booking.startAt))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle(for: booking))
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(store.clientName(for: booking))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(relativeCountdown(for: booking))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(AppFormatters.shortMonthDay(booking.startAt))，\(store.clientName(for: booking))，\(displayTitle(for: booking))"
        )
    }

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("收入")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppTheme.ink)

            HStack(alignment: .top, spacing: 18) {
                revenueMetric(
                    title: "本月",
                    value: snapshot.monthlyRevenue,
                    detail: "已收 \(AppFormatters.currency(snapshot.monthlyReceived))"
                )

                Divider()
                    .frame(height: 58)

                revenueMetric(
                    title: "本年",
                    value: snapshot.yearlyRevenue,
                    detail: nil
                )
            }

            Divider()
        }
    }

    private func revenueMetric(title: String, value: Double, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryInk)
            Text(AppFormatters.currency(value))
                .font(AppTypography.dataCompact)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shootingBrief(for booking: BookingRecord) -> String {
        let title = displayTitle(for: booking)
        let attributes = ShootingAttribute.displayTitle(for: booking.shootingAttributes)

        if attributes == "待补充" { return title }
        return "\(title) · \(attributes)"
    }

    private func displayTitle(for booking: BookingRecord) -> String {
        let title = booking.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return booking.category.title }

        let generatedDatePrefix = AppFormatters.shortDate(booking.startAt)
        guard title.hasPrefix(generatedDatePrefix) else { return title }

        let remainder = title
            .dropFirst(generatedDatePrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? booking.category.title : remainder
    }

    private func crewSummary(for booking: BookingRecord) -> String {
        let assignments = booking.crewAssignments
        guard assignments.isEmpty == false else {
            return store.preferredCrewMemberName.map { "\($0) · 摄影师" } ?? "待安排执行人员"
        }

        let visibleAssignments = assignments.prefix(3).map { assignment in
            "\(assignment.displayName) \(assignment.role.title)"
        }
        let remainingCount = assignments.count - visibleAssignments.count
        let summary = visibleAssignments.joined(separator: "、")
        return remainingCount > 0 ? "\(summary) 等 \(assignments.count) 人" : summary
    }

    private func locationDisplayText(for booking: BookingRecord) -> String {
        let location = booking.fullAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? "地点待补充" : location
    }

    private func navigationDestination(for booking: BookingRecord) -> String? {
        if let latitude = booking.latitude, let longitude = booking.longitude {
            return "\(latitude),\(longitude)"
        }

        let query = booking.navigationQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    private func openNavigation(for booking: BookingRecord) {
        guard let destination = navigationDestination(for: booking) else { return }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "daddr", value: destination),
            URLQueryItem(name: "dirflg", value: "d")
        ]

        guard let url = components.url else { return }
        AppHaptics.tapLight()
        openURL(url)
    }

    private func daysUntilBooking(_ booking: BookingRecord) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: booking.startAt)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func relativeCountdown(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0: "待处理"
        case 0: "今天"
        case 1: "明天"
        default: "\(daysUntilBooking(booking)) 天后"
        }
    }

    private func createBooking() {
        AppHaptics.impactMedium()
        showingNewBooking = true
    }
}
