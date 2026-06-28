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
        Array(snapshot.nextBookings.prefix(5))
    }

    private var todayBookings: [BookingRecord] {
        snapshot.nextBookings.filter { Calendar.current.isDate($0.startAt, inSameDayAs: .now) }
    }

    private var recentBookingsSubtitle: String {
        guard recentBookings.isEmpty == false else { return "等待第一场拍摄" }
        if todayBookings.isEmpty == false {
            return "今天 \(todayBookings.count) 场 · 未来 \(recentBookings.count) 场"
        }
        return "未来 \(recentBookings.count) 场拍摄"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "摄影工作台", topPadding: 10, bottomPadding: 34) {
                heroCard
                recentBookingsSection
            }
            .sheet(isPresented: $showingNewBooking) {
                BookingEditorView()
                    .environment(store)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(heroEyebrowText)
                        .font(AppTypography.micro)
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.72))

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
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.60))
                }
            }

            Divider()
                .overlay(.white.opacity(0.18))

            if let booking = featuredBooking {
                featuredBookingContent(booking)
            } else {
                emptyHeroContent
            }

            Divider()
                .overlay(.white.opacity(0.18))

            heroActionRow
        }
        .padding(24)
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

    private var heroEyebrowText: String {
        if todayBookings.isEmpty == false {
            return "今日 · \(todayBookings.count) 场拍摄"
        }
        return "影期工作台"
    }

    private var heroHeadlineText: String {
        guard let booking = featuredBooking else {
            return "把下一场拍摄\n放进影期"
        }

        switch daysUntilBooking(booking) {
        case ..<0:
            return "这场拍摄\n需要回看处理"
        case 0:
            return "今天开拍\n把现场稳住"
        case 1:
            return "明天开拍\n准备工作就位"
        default:
            return "下一场拍摄\n已经排好节奏"
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(booking.title)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(countdownTitle(for: booking))
                        .font(AppTypography.badge)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 11) {
                heroPlainRow(title: "客户", value: store.clientName(for: booking))
                heroPlainRow(title: "时间", value: "\(AppFormatters.shortMonthDay(booking.startAt)) \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))")
                heroPlainRow(title: "地点", value: navigationQuery(for: booking) ?? "未填写")
            }
        }
    }

    private var emptyHeroContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有即将开始的拍摄")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.white)
            Text("用语音或表单快速新建档期，首页会自动把下一场拍摄顶到最醒目的位置。")
                .font(AppTypography.meta)
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroPlainRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(AppTypography.badge)
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 34, alignment: .leading)
                .padding(.top, 1)
            Text(value)
                .font(AppTypography.rowValue)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var heroActionRow: some View {
        HStack(spacing: 18) {
            heroTextButton(title: "新建档期", systemImage: "calendar.badge.plus") {
                AppHaptics.impactMedium()
                showingNewBooking = true
            }

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 1, height: 24)

            heroTextButton(title: "查看档期", systemImage: "calendar") {
                onOpenSchedule()
            }

            if let booking = featuredBooking, navigationQuery(for: booking) != nil {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: 24)

                heroTextButton(title: "一键导航", systemImage: "location.fill") {
                    openNavigation(for: booking)
                }
            }
        }
    }

    private func heroTextButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppTypography.badge)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .buttonStyle(.plain)
    }

    private var recentBookingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "拍摄排期", subtitle: recentBookingsSubtitle)
                .padding(.bottom, 12)

            if recentBookings.isEmpty {
                emptyScheduleBlock
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentBookings.enumerated()), id: \.element.id) { item in
                        bookingPlainRow(booking: item.element, isFirst: item.offset == 0)
                        if item.offset < recentBookings.count - 1 {
                            rowDivider
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
                }
            }
        }
    }

    private var emptyScheduleBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("暂无排期")
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.ink)
            Text("先创建一场拍摄，首页会自动生成你的工作节奏。")
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private func bookingPlainRow(booking: BookingRecord, isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
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

                Text("客户：\(store.clientName(for: booking))")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)

                Text("地点：\(navigationQuery(for: booking) ?? "未填写地点")")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(countdownTitle(for: booking))
                    .font(AppTypography.badge)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
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
