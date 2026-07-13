import Foundation
import SwiftUI

struct OverviewView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.openURL) private var openURL

    let onOpenSchedule: () -> Void

    @State private var showingNewBooking = false

    private var snapshot: OverviewSnapshot {
        store.overviewSnapshot
    }

    private var featuredBooking: BookingRecord? {
        snapshot.nextBookings.first
    }

    private var recentBookings: [BookingRecord] {
        Array(snapshot.nextBookings.prefix(3))
    }

    private var todayBookings: [BookingRecord] {
        snapshot.nextBookings.filter { Calendar.current.isDate($0.startAt, inSameDayAs: .now) }
    }

    private var recentBookingsSubtitle: String {
        guard recentBookings.isEmpty == false else { return "" }
        if todayBookings.isEmpty == false {
            return "今天 \(todayBookings.count)"
        }
        return "未来 \(recentBookings.count)"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "工作台", topPadding: 10, bottomPadding: 34) {
                heroCard

                if recentBookings.isEmpty == false {
                    recentBookingsSection
                }
            }
            .sheet(isPresented: $showingNewBooking) {
                BookingEditorView()
                    .environment(store)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(heroHeadlineText)
                        .font(AppTypography.heroTitle)
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(heroCountdownNumber)
                        .font(AppTypography.data)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(heroCountdownUnit)
                        .font(AppTypography.micro)
                        .foregroundStyle(.white.opacity(0.60))
                }
            }

            if let booking = featuredBooking {
                featuredBookingContent(booking)
            } else {
                emptyHeroContent
            }

            heroActionRow
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.18), radius: 22, y: 12)
    }

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)

            LinearGradient(
                colors: [.white.opacity(0.10), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))

            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var heroHeadlineText: String {
        guard let booking = featuredBooking else {
            return "下一场\n待安排"
        }

        switch daysUntilBooking(booking) {
        case ..<0:
            return "待复盘"
        case 0:
            return "今天\n开拍"
        case 1:
            return "明天\n开拍"
        default:
            return "下一场\n已排好"
        }
    }

    private var heroCountdownNumber: String {
        guard let booking = featuredBooking else { return "—" }
        switch daysUntilBooking(booking) {
        case ..<0: return "!"
        case 0: return "今"
        default: return "\(daysUntilBooking(booking))"
        }
    }

    private var heroCountdownUnit: String {
        guard let booking = featuredBooking else { return "天后" }
        switch daysUntilBooking(booking) {
        case ..<0: return "待处理"
        case 0: return "今天"
        default: return "天后"
        }
    }

    private func featuredBookingContent(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(booking.title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                heroMetaLine(
                    systemImage: "clock",
                    text: "\(AppFormatters.shortMonthDay(booking.startAt)) \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))"
                )
                heroMetaLine(systemImage: "mappin.and.ellipse", text: navigationQuery(for: booking) ?? "未填地点")
            }
        }
    }

    private var emptyHeroContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 15, weight: .semibold))
            Text("先创建一场拍摄")
                .font(AppTypography.rowValue)
        }
        .foregroundStyle(.white.opacity(0.76))
        .padding(.top, 2)
    }

    private func heroMetaLine(systemImage: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16)
            Text(text)
                .font(AppTypography.meta)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.76))
    }

    private var heroActionRow: some View {
        HStack(spacing: 12) {
            heroIconButton(title: "新建档期", systemImage: "plus") {
                AppHaptics.impactMedium()
                showingNewBooking = true
            }

            heroIconButton(title: "查看档期", systemImage: "calendar") {
                onOpenSchedule()
            }

            if let booking = featuredBooking, navigationQuery(for: booking) != nil {
                heroIconButton(title: "一键导航", systemImage: "location.fill") {
                    openNavigation(for: booking)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func heroIconButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 34)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var recentBookingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "排期", subtitle: recentBookingsSubtitle)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(recentBookings.enumerated()), id: \.element.id) { item in
                    bookingPlainRow(booking: item.element, isFirst: item.offset == 0)
                    if item.offset < recentBookings.count - 1 {
                        rowDivider
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func bookingPlainRow(booking: BookingRecord, isFirst: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormatters.shortMonthDay(booking.startAt))
                    .font(AppTypography.badge)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppTheme.mutedInk)
                    .monospacedDigit()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(booking.title)
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if isFirst {
                        Text("下一场")
                            .font(AppTypography.badge)
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer(minLength: 0)
                }

                Text(compactBookingMeta(for: booking))
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.ink)
                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
            .padding(.leading, 16)
    }

    private func recentBookingLocationText(for booking: BookingRecord) -> String {
        let city = booking.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = booking.venue.trimmingCharacters(in: .whitespacesAndNewlines)

        if venue.isEmpty { return city }
        if city.contains("大庆") { return venue }
        if city.isEmpty { return venue }
        return "\(city) \(venue)"
    }

    private func navigationQuery(for booking: BookingRecord) -> String? {
        let address = booking.fullAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
        if address.isEmpty == false { return address }

        let location = recentBookingLocationText(for: booking).trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? nil : location
    }

    private func compactBookingMeta(for booking: BookingRecord) -> String {
        let client = store.clientName(for: booking)
        let location = navigationQuery(for: booking) ?? "未填地点"
        return "\(client) · \(location)"
    }

    private func openNavigation(for booking: BookingRecord) {
        guard let query = navigationQuery(for: booking),
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encodedQuery)") else {
            return
        }
        AppHaptics.tapLight()
        openURL(url)
    }

    private func countdownTitle(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0:
            return "待复盘"
        case 0:
            return "今天拍摄"
        case 1:
            return "明天开拍"
        default:
            return "\(daysUntilBooking(booking)) 天后"
        }
    }

    private func daysUntilBooking(_ booking: BookingRecord) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: booking.startAt)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }
}
