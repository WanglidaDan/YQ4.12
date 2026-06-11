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
        Array(snapshot.nextBookings.prefix(4))
    }

    private var todayBookings: [BookingRecord] {
        snapshot.nextBookings.filter { Calendar.current.isDate($0.startAt, inSameDayAs: .now) }
    }

    private var recentBookingsSubtitle: String {
        let count = recentBookings.count
        guard count > 0 else { return "等待第一场拍摄" }
        if todayBookings.isEmpty == false {
            return "今天 \(todayBookings.count) 场 · 未来 \(count) 场"
        }
        return "未来 \(count) 场拍摄"
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: "摄影工作台", topPadding: 10, bottomPadding: 34) {
                heroCard
                commandMetricsStrip
                recentBookingsSection
                monthlySummarySection
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
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

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 34, height: 34)
                .background(AppTheme.panelStrong, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: AppTheme.cardShadow.opacity(0.55), radius: 12, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开设置")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.92))
                            .frame(width: 7, height: 7)
                        Text(heroEyebrowText)
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Text(heroHeadlineText)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                heroCountdownBadge
            }

            if let booking = featuredBooking {
                featuredBookingPanel(booking)
            } else {
                emptyHeroPanel
            }

            heroActionRow
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.24), radius: 28, y: 18)
    }

    private var heroBackground: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 170, height: 170)
                .offset(x: 74, y: -84)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 118, height: 118)
                .offset(x: -214, y: 146)

            LinearGradient(
                colors: [.white.opacity(0.18), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))

            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
    }

    private var heroEyebrowText: String {
        if todayBookings.isEmpty == false {
            return "TODAY · \(todayBookings.count) 场拍摄"
        }
        return "YINGQI STUDIO"
    }

    private var heroHeadlineText: String {
        if let booking = featuredBooking {
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
        return "把下一场拍摄\n放进影期"
    }

    @ViewBuilder
    private var heroCountdownBadge: some View {
        if let booking = featuredBooking {
            VStack(spacing: 4) {
                Text(heroCountdownNumber(for: booking))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(heroCountdownUnit(for: booking))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .frame(width: 70, height: 70)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
        } else {
            Image(systemName: "camera.aperture")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func featuredBookingPanel(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(booking.title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.clientName(for: booking))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(countdownTitle(for: booking))
                    .font(AppTypography.badge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.20), lineWidth: 1)
                    }
            }

            VStack(spacing: 10) {
                heroDetailRow(systemImage: "clock.fill", title: "拍摄时间", value: "\(AppFormatters.shortMonthDay(booking.startAt)) \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))")
                heroDetailRow(systemImage: "mappin.and.ellipse", title: "拍摄地点", value: recentBookingLocationText(for: booking))
            }
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var emptyHeroPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还没有即将开始的拍摄")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("用语音或表单快速新建档期，首页会自动把下一场拍摄顶到最醒目的位置。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.80))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func heroDetailRow(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.14), in: Circle())

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 8)

            Text(value.isEmpty ? "未填写" : value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }

    private var heroActionRow: some View {
        HStack(spacing: 10) {
            heroActionButton(
                title: "新建档期",
                systemImage: "calendar.badge.plus",
                tint: .white.opacity(0.20),
                foreground: .white
            ) {
                AppHaptics.impactMedium()
                showingNewBooking = true
            }

            heroActionButton(
                title: "打开档期",
                systemImage: "calendar",
                tint: .white.opacity(0.13),
                foreground: .white
            ) {
                onOpenSchedule()
            }
        }
    }

    private var commandMetricsStrip: some View {
        HStack(spacing: 10) {
            dashboardMetricTile(title: "本月成交", value: AppFormatters.currency(snapshot.monthlyRevenue), symbol: "chart.line.uptrend.xyaxis", tint: AppTheme.accent)
            dashboardMetricTile(title: "待收", value: AppFormatters.currency(snapshot.monthlyOutstanding), symbol: "creditcard", tint: snapshot.monthlyOutstanding > 0 ? AppTheme.warning : AppTheme.success)
            dashboardMetricTile(title: "未来档期", value: "\(snapshot.nextBookings.count)", symbol: "calendar", tint: AppTheme.info)
        }
    }

    private func dashboardMetricTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow.opacity(0.52), radius: 16, y: 8)
    }

    private var recentBookingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "拍摄排期", subtitle: recentBookingsSubtitle, actionTitle: "全部") {
                onOpenSchedule()
            }

            if recentBookings.isEmpty {
                emptyScheduleCard
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(recentBookings.enumerated()), id: \.element.id) { index, booking in
                        premiumBookingRow(booking: booking, index: index)
                    }
                }
            }
        }
    }

    private var emptyScheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.accentSurface, in: Circle())

            Text("暂无排期")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)

            Text("先创建一场拍摄，首页会自动生成你的工作节奏。")
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        }
    }

    private func premiumBookingRow(booking: BookingRecord, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Text(AppFormatters.shortMonthDay(booking.startAt))
                    .font(.caption.weight(.black))
                    .foregroundStyle(index == 0 ? .white : AppTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(index == 0 ? .white.opacity(0.78) : AppTheme.mutedInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 72, height: 64)
            .background(index == 0 ? AppTheme.heroGradient : AppTheme.accentSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(index == 0 ? Color.white.opacity(0.18) : AppTheme.line.opacity(0.55), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(booking.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Text(recentBookingCountdownText(for: booking))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(index == 0 ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                HStack(spacing: 7) {
                    Label(store.clientName(for: booking), systemImage: "person.fill")
                    Text("·")
                    Label(recentBookingLocationText(for: booking).isEmpty ? "未填写地点" : recentBookingLocationText(for: booking), systemImage: "mappin")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }
            .padding(.top, 3)
        }
        .padding(14)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(index == 0 ? AppTheme.accent.opacity(0.28) : AppTheme.line.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow.opacity(index == 0 ? 0.70 : 0.38), radius: index == 0 ? 18 : 10, y: index == 0 ? 9 : 5)
    }

    private var monthlySummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "本月经营", subtitle: AppFormatters.monthYear(.now), actionTitle: "档期") {
                onOpenSchedule()
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("成交金额")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text(AppFormatters.currency(snapshot.monthlyRevenue))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 4) {
                        Text("\(snapshot.monthlyBookedCount)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                        Text("订单")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .frame(width: 60, height: 60)
                    .background(AppTheme.accentSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(summaryProgressText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                        Text(summaryDescriptionText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    monthlyProgressLine(progress: summaryProgressRatio)
                }

                HStack(alignment: .top, spacing: 12) {
                    summaryMiniTile(title: "已收", value: AppFormatters.currency(snapshot.monthlyReceived), tint: AppTheme.success)
                    summaryMiniTile(title: "待收", value: AppFormatters.currency(snapshot.monthlyOutstanding), tint: snapshot.monthlyOutstanding > 0 ? AppTheme.warning : AppTheme.success)
                }

                Text(monthlySummaryHintText)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(20)
            .background(AppTheme.panelGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
            }
            .shadow(color: AppTheme.cardShadow.opacity(0.62), radius: 20, y: 10)
        }
    }

    private func sectionHeader(title: String, subtitle: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer(minLength: 0)

            Button(action: action) {
                HStack(spacing: 5) {
                    Text(actionTitle)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(AppTheme.accentSurface, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryMiniTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var summaryProgressRatio: CGFloat {
        guard snapshot.monthlyRevenue > 0 else { return 0 }
        return CGFloat(min(snapshot.monthlyReceived / snapshot.monthlyRevenue, 1))
    }

    private var summaryProgressText: String {
        guard snapshot.monthlyRevenue > 0 else { return "暂无成交额" }
        let percentage = Int((summaryProgressRatio * 100).rounded())
        return "回款进度 \(percentage)%"
    }

    private var monthlySummaryHintText: String {
        if snapshot.monthlyRevenue <= 0 {
            return "新建档期后，这里会自动汇总本月成交、已收和待收。"
        }
        if snapshot.monthlyOutstanding > 0 {
            return "本月已有成交，下一步建议重点跟进待收款和交付节点。"
        }
        return "本月回款状态较完整，可以继续保持当前交付节奏。"
    }

    private var summaryDescriptionText: String {
        if snapshot.monthlyRevenue <= 0 {
            return "暂无经营数据"
        }
        return "已收 \(AppFormatters.currency(snapshot.monthlyReceived))"
    }

    private func monthlyProgressLine(progress: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.line.opacity(0.40))
                Capsule()
                    .fill(AppTheme.heroGradient)
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 9)
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

    private func heroCountdownNumber(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0:
            return "!"
        case 0:
            return "今"
        default:
            return "\(daysUntilBooking(booking))"
        }
    }

    private func heroCountdownUnit(for booking: BookingRecord) -> String {
        switch daysUntilBooking(booking) {
        case ..<0:
            return "待处理"
        case 0:
            return "TODAY"
        default:
            return "DAYS"
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
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppTypography.meta.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
