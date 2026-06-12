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
                operatingLedger
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开设置")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(heroEyebrowText)
                        .font(.caption.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.76))

                    Text(heroHeadlineText)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(heroCountdownNumber)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(heroCountdownUnit)
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.62))
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

            HStack(spacing: 22) {
                heroTextButton(title: "新建档期", systemImage: "calendar.badge.plus") {
                    AppHaptics.impactMedium()
                    showingNewBooking = true
                }

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: 24)

                heroTextButton(title: "打开档期", systemImage: "calendar") {
                    onOpenSchedule()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.18), radius: 22, y: 12)
    }

    private var heroBackground: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 168, height: 168)
                .offset(x: 76, y: -86)

            LinearGradient(
                colors: [.white.opacity(0.12), .clear, .black.opacity(0.08)],
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
            return "TODAY · \(todayBookings.count) 场拍摄"
        }
        return "YINGQI STUDIO"
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
        guard let booking = featuredBooking else { return "DAYS" }
        switch daysUntilBooking(booking) {
        case ..<0: return "待处理"
        case 0: return "TODAY"
        default: return "DAYS"
        }
    }

    private func featuredBookingContent(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(booking.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text(countdownTitle(for: booking))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
            }

            VStack(spacing: 10) {
                heroPlainRow(title: "客户", value: store.clientName(for: booking))
                heroPlainRow(title: "时间", value: "\(AppFormatters.shortMonthDay(booking.startAt)) \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))")
                heroPlainRow(title: "地点", value: recentBookingLocationText(for: booking).isEmpty ? "未填写" : recentBookingLocationText(for: booking))
            }
        }
    }

    private var emptyHeroContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有即将开始的拍摄")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("用语音或表单快速新建档期，首页会自动把下一场拍摄顶到最醒目的位置。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroPlainRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 0)
        }
    }

    private func heroTextButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private var operatingLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "经营概览", subtitle: "统一口径")
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ledgerRow(title: "本月成交", value: AppFormatters.currency(snapshot.monthlyRevenue))
                rowDivider
                ledgerRow(title: "待收金额", value: AppFormatters.currency(snapshot.monthlyOutstanding))
                rowDivider
                ledgerRow(title: "未来档期", value: "\(snapshot.nextBookings.count) 场")
            }
            .padding(.vertical, 4)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
            }
        }
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
                .font(.system(size: 17, weight: .bold, design: .rounded))
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
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(booking.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)

                    if isFirst {
                        Text("下一场")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer(minLength: 0)
                }

                Text("\(store.clientName(for: booking)) · \(recentBookingLocationText(for: booking).isEmpty ? "未填写地点" : recentBookingLocationText(for: booking))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private var monthlySummarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "本月经营", subtitle: AppFormatters.monthYear(.now))
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("成交金额")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.mutedInk)
                    Text(AppFormatters.currency(snapshot.monthlyRevenue))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                monthlyProgressLine(progress: summaryProgressRatio)

                VStack(spacing: 0) {
                    ledgerRow(title: "订单数", value: "\(snapshot.monthlyBookedCount) 单")
                    rowDivider
                    ledgerRow(title: "已收", value: AppFormatters.currency(snapshot.monthlyReceived))
                    rowDivider
                    ledgerRow(title: "待收", value: AppFormatters.currency(snapshot.monthlyOutstanding))
                }

                Text(monthlySummaryHintText)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer(minLength: 0)
        }
    }

    private func ledgerRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
            .padding(.leading, 16)
    }

    private var summaryProgressRatio: CGFloat {
        guard snapshot.monthlyRevenue > 0 else { return 0 }
        return CGFloat(min(snapshot.monthlyReceived / snapshot.monthlyRevenue, 1))
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

    private func monthlyProgressLine(progress: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.line.opacity(0.44))
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 8)
    }

    private func recentBookingLocationText(for booking: BookingRecord) -> String {
        let city = booking.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = booking.venue.trimmingCharacters(in: .whitespacesAndNewlines)

        if venue.isEmpty { return city }
        if city.contains("大庆") { return venue }
        if city.isEmpty { return venue }
        return "\(city) \(venue)"
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
