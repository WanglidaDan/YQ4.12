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

    private var actionBoardSubtitle: String {
        if snapshot.pendingActions.allSatisfy({ $0.valueText == "0" || $0.valueText == AppFormatters.currency(0) }) {
            return "当前节奏很干净"
        }
        return "跟进、交付、回款一眼看清"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "摄影工作台", topPadding: 14, bottomPadding: 32) {
                heroCard
                actionBoardSection
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

    private var actionBoardSection: some View {
        GlassCard(title: "今日经营动作", subtitle: actionBoardSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                if snapshot.pendingActions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今天没有必须处理的事项")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                        Text("保持当前节奏，新的拍摄、跟进和回款会自动汇总到这里。")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(snapshot.pendingActions) { item in
                            actionTile(item)
                        }
                    }
                }

                if let receivable = snapshot.receivableBookings.first, snapshot.monthlyOutstanding > 0 {
                    Divider()
                        .overlay(AppTheme.line.opacity(0.58))
                        .padding(.vertical, 2)

                    Button {
                        onOpenSchedule()
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "banknote")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.accentSurface, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("优先回款")
                                    .font(AppTypography.meta.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("\(receivable.title) 还有尾款需要跟进")
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionTile(_ item: OverviewActionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentSurface, in: Circle())

                Spacer(minLength: 0)

                Text(item.valueText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 18, fillColor: AppTheme.panel)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("成交金额")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Spacer(minLength: 8)

                    Text("\(snapshot.monthlyBookedCount) 单")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(AppTheme.accentSurface, in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppFormatters.currency(snapshot.monthlyRevenue))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text(monthlySummaryHintText)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .overlay(AppTheme.line.opacity(0.58))

                HStack(alignment: .top, spacing: 14) {
                    flatMonthlyMetric(title: "已收", value: AppFormatters.currency(snapshot.monthlyReceived), suffix: nil)
                    flatMetricDivider
                    flatMonthlyMetric(title: "待收", value: AppFormatters.currency(snapshot.monthlyOutstanding), suffix: nil)
                }

                Button {
                    onOpenSchedule()
                } label: {
                    HStack(spacing: 8) {
                        Text("查看档期")
                            .font(AppTypography.meta.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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

    private var monthlySummaryHintText: String {
        if snapshot.monthlyRevenue <= 0 {
            return "新建档期后，这里会自动汇总本月经营情况。"
        }
        if snapshot.monthlyOutstanding > 0 {
            return "本月经营已形成记录，下一步重点关注回款和交付。"
        }
        return "本月经营已形成记录，回款状态较完整。"
    }

    private var summaryDescriptionText: String {
        if snapshot.monthlyRevenue <= 0 {
            return "本月暂未形成成交，新增档期后这里会自动汇总。"
        }
        return "已收 \(AppFormatters.currency(snapshot.monthlyReceived)) · 待收 \(AppFormatters.currency(snapshot.monthlyOutstanding))"
    }

    private var flatMetricDivider: some View {
        Rectangle()
            .fill(AppTheme.line.opacity(0.52))
            .frame(width: 1, height: 36)
    }

    private func flatMonthlyMetric(title: String, value: String, suffix: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                if let suffix {
                    Text(suffix)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthlyProgressLine(progress: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.line.opacity(0.38))
                Capsule()
                    .fill(AppTheme.heroGradient)
                    .frame(width: max(6, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 7)
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