import SwiftUI

struct OverviewView: View {
    @Environment(StudioStore.self) private var store

    let onOpenSchedule: () -> Void

    @State private var showingNewBooking = false
    @State private var showingSettings = false

    private var snapshot: OverviewSnapshot {
        store.overviewSnapshot
    }

    private var featuredBooking: BookingRecord? {
        snapshot.nextBookings.first
    }

    private var recentBookings: [BookingRecord] {
        Array(snapshot.nextBookings.prefix(3))
    }

    private var recentBookingsSubtitle: String {
        let count = recentBookings.count
        guard count > 0 else { return "未来暂无拍摄" }
        return "未来 \(count) 场拍摄"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "摄影工作台", topPadding: 14, bottomPadding: 32) {
                heroCard
                recentBookingsSection
                monthlySummarySection
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.panel, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.line.opacity(0.82), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开设置")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
                    .environment(store)
            }
            .sheet(isPresented: $showingNewBooking) {
                BookingEditorView()
                    .environment(store)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(featuredBooking == nil ? "近期暂无拍摄" : "下一场拍摄")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                if let booking = featuredBooking {
                    countdownPill(for: booking)
                }
            }

            if let booking = featuredBooking {
                VStack(alignment: .leading, spacing: 16) {
                    Text(booking.title)
                        .font(AppTypography.heroTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        heroInfoRow(title: "客户", value: store.clientName(for: booking))
                        heroInfoRow(title: "时间", value: "\(AppFormatters.shortMonthDay(booking.startAt)) \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))")
                        heroInfoRow(title: "地点", value: recentBookingLocationText(for: booking))
                    }
                }
            } else {
                Text("新建档期后自动聚焦下一场。")
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                heroActionButton(
                    title: "新建档期",
                    systemImage: "calendar.badge.plus",
                    tint: .white.opacity(0.18),
                    foreground: .white
                ) {
                    AppHaptics.impactMedium()
                    showingNewBooking = true
                }

                heroActionButton(
                    title: "打开档期",
                    systemImage: "calendar",
                    tint: .white.opacity(0.14),
                    foreground: .white
                ) {
                    onOpenSchedule()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)

            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepShadow.opacity(0.14), radius: AppShadow.heroRadius, y: AppShadow.heroY)
    }

    private var recentBookingsSection: some View {
        GlassCard(title: "最近档期", subtitle: recentBookingsSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                if recentBookings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("暂无最近档期")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                        Text("新建后自动显示。")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(recentBookings.enumerated()), id: \.element.id) { index, booking in
                            VStack(spacing: 0) {
                                recentBookingTimelineRow(
                                    booking: booking,
                                    isFirst: index == 0,
                                    isLast: index == recentBookings.count - 1
                                )

                                if index < recentBookings.count - 1 {
                                    Divider()
                                        .overlay(AppTheme.line.opacity(0.72))
                                        .padding(.leading, 26)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthlySummarySection: some View {
        GlassCard(title: "本月经营摘要", subtitle: AppFormatters.monthYear(.now)) {
            VStack(alignment: .leading, spacing: 14) {
                monthlyHeadlineCard

                HStack(spacing: 0) {
                    compactMonthlyMetric(title: "订单", value: "\(snapshot.monthlyBookedCount)", suffix: "单")
                    monthlyMetricDivider
                    compactMonthlyMetric(title: "已收", value: AppFormatters.currency(snapshot.monthlyReceived), suffix: nil)
                    monthlyMetricDivider
                    compactMonthlyMetric(title: "待收", value: AppFormatters.currency(snapshot.monthlyOutstanding), suffix: nil)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(AppTheme.panelSoft, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Button {
                    onOpenSchedule()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text("查看经营详情")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.52), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthlyHeadlineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("本月成交额")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                Spacer(minLength: 8)
                Text(summaryProgressText)
                    .font(AppTypography.badge)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSurface, in: Capsule())
            }

            Text(AppFormatters.currency(snapshot.monthlyRevenue))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            monthlyProgressBar(progress: summaryProgressRatio)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.line.opacity(0.5), lineWidth: 1)
        }
    }

    private var monthlyMetricDivider: some View {
        Rectangle()
            .fill(AppTheme.line.opacity(0.58))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 10)
    }

    private func compactMonthlyMetric(title: String, value: String, suffix: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let suffix {
                    Text(suffix)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryProgressRatio: CGFloat {
        guard snapshot.monthlyRevenue > 0 else { return 0 }
        return CGFloat(min(snapshot.monthlyReceived / snapshot.monthlyRevenue, 1))
    }

    private var summaryProgressText: String {
        guard snapshot.monthlyRevenue > 0 else { return "暂无成交额" }
        let percentage = Int((summaryProgressRatio * 100).rounded())
        return "已收 \(percentage)%"
    }

    private func monthlyProgressBar(progress: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.line.opacity(0.4))
                    Capsule()
                        .fill(AppTheme.heroGradient)
                        .frame(width: max(6, proxy.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 8)

            HStack {
                Text("已收 \(AppFormatters.currency(snapshot.monthlyReceived))")
                Spacer(minLength: 8)
                Text("待收 \(AppFormatters.currency(snapshot.monthlyOutstanding))")
            }
            .font(AppTypography.meta)
            .foregroundStyle(AppTheme.secondaryInk)
        }
    }

    private func recentBookingTimelineRow(booking: BookingRecord, isFirst: Bool, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                timelineRail(isFirst: isFirst, isLast: isLast)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(AppFormatters.shortMonthDay(booking.startAt))
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .lineLimit(1)

                        Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                            .font(AppTypography.meta.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(recentBookingCountdownText(for: booking))
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }

                    Text(booking.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(store.clientName(for: booking))
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineLimit(1)

                        Text("·")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)

                        Text(recentBookingLocationText(for: booking))
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRail(isFirst: Bool, isLast: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(AppTheme.heroGradient)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                }
                .padding(.top, 3)

            Rectangle()
                .fill(AppTheme.line.opacity(0.76))
                .frame(width: 1, height: 44)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 14, height: 63, alignment: .top)
    }

    private func recentBookingLocationText(for booking: BookingRecord) -> String {
        let city = booking.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = booking.venue.trimmingCharacters(in: .whitespacesAndNewlines)

        if venue.isEmpty { return city }
        if city.contains("大庆") { return venue }
        if city.isEmpty { return venue }
        return "\(city) \(venue)"
    }

    private func recentBookingCountdownText(for booking: BookingRecord) -> String {
        let raw = AppFormatters.countdownText(to: booking.startAt)
        return raw
            .replacingOccurrences(of: " 天后", with: "天")
            .replacingOccurrences(of: "1 天后", with: "1天")
    }

    private func heroInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func countdownPill(for booking: BookingRecord) -> some View {
        HStack(spacing: 6) {
            Image(systemName: countdownSymbolName(for: booking))
                .font(.caption.weight(.semibold))
            Text(countdownTitle(for: booking))
                .font(AppTypography.badge)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.16), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.26), lineWidth: 1)
        }
    }

    private func countdownTitle(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0:
            return "已到拍摄日"
        case 0:
            return "今天拍摄"
        case 1:
            return "明天开拍"
        default:
            return "距拍摄还有 \(daysUntilBooking(booking)) 天"
        }
    }

    private func countdownSymbolName(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0:
            return "exclamationmark.triangle.fill"
        case 0:
            return "clock.fill"
        case 1:
            return "sunrise.fill"
        default:
            return "calendar.badge.clock"
        }
    }

    private func daysUntilBooking(_ booking: BookingRecord) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: booking.startAt)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func heroActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
