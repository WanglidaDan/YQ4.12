import SwiftUI
import UIKit
import CoreLocation

struct OverviewView: View {
    @Environment(StudioStore.self) private var store

    let onOpenSchedule: () -> Void

    @State private var showingNewBooking = false
    @State private var showingSettings = false
    @State private var reminderBooking: BookingRecord?
    @State private var contactErrorMessage: String?
    @State private var navigationSheetBooking: BookingRecord?

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
        store.bookings(on: .now)
    }

    private var isTeamModeEnabled: Bool {
        store.settings.studioModeEnabled
    }

    private var currentCrewMemberName: String? {
        store.preferredCrewMemberName
    }

    private var myTodayBookings: [BookingRecord] {
        guard let memberName = currentCrewMemberName else { return [] }
        return store.bookings(on: .now, assignedTo: memberName)
    }

    private var otherTodayBookings: [BookingRecord] {
        guard currentCrewMemberName != nil else { return todayBookings }
        let myIDs = Set(myTodayBookings.map(\.id))
        return todayBookings.filter { myIDs.contains($0.id) == false }
    }

    fileprivate enum NavigationMapChoice: String, CaseIterable, Identifiable {
        case apple
        case amap
        case baidu
        case tencent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apple: "苹果地图"
            case .amap: "高德地图"
            case .baidu: "百度地图"
            case .tencent: "腾讯地图"
            }
        }

        var symbolName: String {
            switch self {
            case .apple: "map.fill"
            case .amap: "location.fill"
            case .baidu: "mappin.and.ellipse"
            case .tencent: "globe.asia.australia.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    heroCard
                    recentBookingsSection
                    monthlySummarySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .background(overviewBackdrop.ignoresSafeArea())
            .navigationTitle("摄影工作台")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(item: $reminderBooking) { booking in
                BookingReminderSheet(
                    booking: booking,
                    client: booking.clientID.flatMap { store.client(id: $0) },
                    monthBookings: store.bookings(inMonthContaining: booking.startAt, includeArchived: false),
                    onContact: { contactClient(for: booking) },
                    onNavigate: { openNavigationSheet(for: booking) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $navigationSheetBooking) { booking in
                NavigationMapSheet(
                    booking: booking,
                    onChoose: { choice in
                        navigationSheetBooking = nil
                        openNavigation(for: booking, via: choice)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert(
                "联系客户",
                isPresented: Binding(
                    get: { contactErrorMessage != nil },
                    set: { if $0 == false { contactErrorMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(contactErrorMessage ?? "")
            }
        }
    }

    private var overviewBackdrop: some View {
        ZStack {
            AppTheme.background

            StudioBackdrop(mode: .ambient)
                .opacity(0.18)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color(red: 0.99, green: 0.99, blue: 0.97).opacity(0.26),
                    Color.clear,
                    Color(red: 0.97, green: 0.99, blue: 0.98).opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 420
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.99, blue: 0.97).opacity(0.30),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .blendMode(.screen)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppFormatters.day(.now))
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(featuredBooking == nil ? "近期暂无下一场拍摄" : "下一场拍摄提醒")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                if let booking = featuredBooking {
                    countdownPill(for: booking)
                }
            }

            if let booking = featuredBooking {
                Button {
                    reminderBooking = booking
                } label: {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(booking.title)
                                .font(AppTypography.heroTitle)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            heroInfoRow(title: "客户", value: store.clientName(for: booking))
                            heroInfoRow(title: "时间", value: AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                            heroInfoRow(title: "地点", value: "\(booking.city) \(booking.venue)")
                            heroInfoRow(title: "拍摄内容", value: ShootingAttribute.displayTitle(for: booking.shootingAttributes))
                            if isTeamModeEnabled, booking.crewAssignments.isEmpty == false {
                                heroInfoRow(title: "工作分工", value: crewAssignmentSummary(for: booking))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("先把接下来要拍的项目排进来，提醒会在这里自动聚焦。")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
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

                if let booking = featuredBooking {
                    heroActionButton(
                        title: "联系客户",
                        systemImage: "phone.fill",
                        tint: .white.opacity(0.14),
                        foreground: .white
                    ) {
                        contactClient(for: booking)
                    }

                    heroActionButton(
                        title: "一键导航",
                        systemImage: "location.fill",
                        tint: .white.opacity(0.14),
                        foreground: .white
                    ) {
                        openNavigationSheet(for: booking)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .fill(AppTheme.heroGradient)

            RadialGradient(
                colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.91).opacity(0.18),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 12,
                endRadius: 180
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .blur(radius: 20)
                .offset(x: 132, y: 116)

            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepShadow.opacity(0.22), radius: AppShadow.heroRadius, y: AppShadow.heroY)
    }

    private var todayDispatchSection: some View {
        GlassCard(title: isTeamModeEnabled ? "团队分工" : "今日安排", subtitle: todayDispatchSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    if isTeamModeEnabled, let currentCrewMemberName {
                        AppInlineNote(systemImage: "person.crop.circle.fill", text: "当前成员：\(currentCrewMemberName)")
                    } else if isTeamModeEnabled {
                        AppInlineNote(systemImage: "person.crop.circle.badge.questionmark", text: "未选择当前成员，先去“我的”里指定自己是谁。")
                    } else {
                        AppInlineNote(systemImage: "calendar", text: "当前为个人模式，这里直接展示今天全部安排。")
                    }

                    Spacer(minLength: 8)

                    Button("打开档期") {
                        onOpenSchedule()
                    }
                    .buttonStyle(AppGhostButtonStyle())
                }

                if todayBookings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今天暂无拍摄安排")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                        Text("当日有多场拍摄时，这里会直接告诉你自己该去哪场、团队其他人在拍什么。")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if let currentCrewMemberName, myTodayBookings.isEmpty {
                            AppInlineNote(systemImage: "person.crop.circle.badge.xmark", text: "\(currentCrewMemberName) 今天暂未被分配，继续看团队其他安排。")
                        }
                        if currentCrewMemberName != nil, myTodayBookings.isEmpty == false {
                            todayDispatchGroup(title: "我的安排", bookings: myTodayBookings, highlight: true)
                        }
                        if otherTodayBookings.isEmpty == false {
                            todayDispatchGroup(
                                title: isTeamModeEnabled ? (currentCrewMemberName == nil ? "团队其他安排" : "团队其他安排") : "今日安排",
                                bookings: otherTodayBookings,
                                highlight: false
                            )
                        }
                    }
                }
            }
        }
    }

    private var todayDispatchSubtitle: String {
        if isTeamModeEnabled == false {
            return todayBookings.isEmpty ? "当前没有排班" : "个人模式下按今日日期聚合全部项目。"
        }
        if currentCrewMemberName != nil {
            return todayBookings.isEmpty ? "当前没有排班" : "快速查看我的安排与团队其他安排。"
        }
        return todayBookings.isEmpty ? "当前没有排班" : "适合工作室快速查看我的安排与团队其他安排。"
    }

    private func todayDispatchGroup(title: String, bookings: [BookingRecord], highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(bookings.count) 场")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            VStack(spacing: 10) {
                ForEach(bookings) { booking in
                    todayDispatchRow(booking, highlight: highlight)
                }
            }
        }
    }

    private func todayDispatchRow(_ booking: BookingRecord, highlight: Bool) -> some View {
        let personalSummary = currentCrewMemberName.flatMap { memberName in
            let assignments = store.assignments(for: booking, matching: memberName)
            return assignments.isEmpty ? nil : assignments.map(\.operationalSummaryText).joined(separator: " / ")
        }
        let teamSummary = (isTeamModeEnabled && booking.crewAssignments.isEmpty == false) ? crewAssignmentSummary(for: booking) : nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if highlight {
                    Text("我的安排")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentSurface, in: Capsule())
                }
            }

            Text(booking.title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.clientName(for: booking))
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)

            Text(booking.venue.isEmpty ? booking.fullAddressText : booking.venue)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)

            if let personalSummary {
                AppInlineNote(systemImage: "person.crop.circle.badge.checkmark", text: personalSummary, tint: AppTheme.accentWarmDeep)
            } else if let teamSummary {
                AppInlineNote(systemImage: "person.3.fill", text: teamSummary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(highlight ? AppTheme.accentSoft.opacity(0.9) : AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke((highlight ? AppTheme.accent.opacity(0.22) : AppTheme.line.opacity(0.55)), lineWidth: 1)
        }
    }

    private var recentBookingsSection: some View {
        GlassCard(title: "最近档期", subtitle: "未来 3 场拍摄") {
            VStack(alignment: .leading, spacing: 12) {
                if recentBookings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("暂无最近档期")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                        Text("新建拍摄后，这里会按时间轴自动显示未来最近的 3 场。")
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
        VStack(spacing: 4) {
            Rectangle()
                .fill(AppTheme.line.opacity(0.76))
                .frame(width: 1)
                .frame(height: 8)
                .opacity(isFirst ? 0 : 1)

            Circle()
                .fill(AppTheme.heroGradient)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                }

            Rectangle()
                .fill(AppTheme.line.opacity(0.76))
                .frame(width: 1)
                .frame(height: 8)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 14, height: 34)
    }

    private func recentBookingLocationText(for booking: BookingRecord) -> String {
        let city = booking.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = booking.venue.trimmingCharacters(in: .whitespacesAndNewlines)

        if venue.isEmpty {
            return city
        }

        if city.contains("大庆") {
            return venue
        }

        if city.isEmpty {
            return venue
        }

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

    private func crewAssignmentSummary(for booking: BookingRecord) -> String {
        let normalized = BookingCrewAssignment.normalized(booking.crewAssignments)
        guard normalized.isEmpty == false else { return "待安排" }

        let heads = normalized.prefix(2).map { "\($0.displayName)·\($0.role.title)" }
        if normalized.count > 2 {
            return heads.joined(separator: "、") + "、+\(normalized.count - 2)"
        }
        return heads.joined(separator: "、")
    }

    private func countdownPill(for booking: BookingRecord) -> some View {
        return HStack(spacing: 6) {
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

    private var summaryProgressRatio: CGFloat {
        guard snapshot.monthlyRevenue > 0 else { return 0 }
        return CGFloat(min(snapshot.monthlyReceived / snapshot.monthlyRevenue, 1))
    }

    private var summaryProgressText: String {
        guard snapshot.monthlyRevenue > 0 else { return "暂无成交额" }
        let percentage = Int((summaryProgressRatio * 100).rounded())
        return "已收 \(percentage)%"
    }

    private var revenueRingProgress: CGFloat {
        guard snapshot.monthlyRevenue > 0 else { return 0 }
        let benchmark = max(50_000, ceil(snapshot.monthlyRevenue / 50_000) * 50_000)
        return CGFloat(min(snapshot.monthlyRevenue / benchmark, 1))
    }

    private var monthlySummarySection: some View {
        GlassCard(title: "本月经营摘要", subtitle: AppFormatters.monthYear(.now)) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("经营仪表盘")
                            .font(AppTypography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text("成交进度与回款节奏")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppTheme.ink)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppFormatters.currency(snapshot.monthlyRevenue))
                            .font(AppTypography.data)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("本月成交额")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    summaryRing(
                        title: "成交额",
                        value: AppFormatters.currency(snapshot.monthlyRevenue),
                        subtitle: "本月累计",
                        progress: revenueRingProgress,
                        highlight: AppTheme.success
                    )

                    summaryRing(
                        title: "回款率",
                        value: summaryProgressText,
                        subtitle: "收款进度",
                        progress: summaryProgressRatio,
                        highlight: AppTheme.accent
                    )
                }

                HStack(spacing: 12) {
                    statPill(title: "订单数", value: "\(snapshot.monthlyBookedCount)")
                    statPill(title: "待收额", value: AppFormatters.currency(snapshot.monthlyOutstanding))
                }
            }
        }
    }

    private func summaryRing(
        title: String,
        value: String,
        subtitle: String,
        progress: CGFloat,
        highlight: Color
    ) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppTheme.line.opacity(0.38), lineWidth: 11)

                Circle()
                    .trim(from: 0, to: progress == 0 ? 0 : max(progress, 0.08))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.82, green: 0.95, blue: 0.68),
                                Color(red: 0.44, green: 0.78, blue: 0.39)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(value)
                        .font(AppTypography.dataCompact)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 132, height: 132)

            VStack(spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Text(progress == 0 ? "暂无数据" : progress >= 1 ? "阶段满格" : "绿色进度")
                    .font(AppTypography.meta)
                    .foregroundStyle(highlight)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statPill(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 0)
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.55), lineWidth: 1)
        }
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

    private func contactClient(for booking: BookingRecord) {
        guard let client = booking.clientID.flatMap({ store.client(id: $0) }) else {
            contactErrorMessage = "这条档期还没有绑定客户，暂时无法拨号。"
            AppHaptics.error()
            return
        }

        let digits = AppFormatters.sanitizedPhoneNumber(client.phoneNumber)
        guard digits.isEmpty == false,
              let url = URL(string: "tel://\(digits)") else {
            contactErrorMessage = "\(client.name) 还没有可用的联系电话。"
            AppHaptics.error()
            return
        }
        AppHaptics.impactMedium()
        UIApplication.shared.open(url) { success in
            if success == false {
                contactErrorMessage = "当前设备无法直接拨号，请到客户详情里手动联系。"
                AppHaptics.error()
            }
        }
    }

    private func openNavigationSheet(for booking: BookingRecord) {
        navigationSheetBooking = booking
    }

    private func openNavigation(for booking: BookingRecord, via choice: NavigationMapChoice) {
        let query = booking.navigationQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return }

        let coordinate = booking.coordinate
        let fallbackURL = appleMapsURL(for: booking, query: query, coordinate: coordinate)
        let url = navigationURL(for: booking, via: choice, query: query, coordinate: coordinate) ?? fallbackURL

        AppHaptics.impactMedium()
        UIApplication.shared.open(url) { success in
            if success == false && choice != .apple {
                UIApplication.shared.open(fallbackURL)
            }
        }
    }

    private func navigationURL(
        for booking: BookingRecord,
        via choice: NavigationMapChoice,
        query: String,
        coordinate: CLLocationCoordinate2D?
    ) -> URL? {
        let encodedName = (booking.venue.isEmpty ? booking.title : booking.venue)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? booking.title
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        switch choice {
        case .apple:
            return appleMapsURL(for: booking, query: query, coordinate: coordinate)
        case .amap:
            if let coordinate {
                return URL(string: "iosamap://path?sourceApplication=YingQi&dlat=\(coordinate.latitude)&dlon=\(coordinate.longitude)&dname=\(encodedName)&dev=0&t=0")
            }
            return URL(string: "iosamap://search?sourceApplication=YingQi&keyword=\(encodedQuery)")
        case .baidu:
            if let coordinate {
                return URL(string: "baidumap://map/direction?destination=latlng:\(coordinate.latitude),\(coordinate.longitude)|\(encodedName)&mode=driving&src=YingQi")
            }
            return URL(string: "baidumap://map/search?query=\(encodedQuery)&src=YingQi")
        case .tencent:
            if let coordinate {
                return URL(string: "qqmap://map/routeplan?type=drive&tocoord=\(coordinate.latitude),\(coordinate.longitude)&to=\(encodedName)&policy=0&referer=YingQi")
            }
            return URL(string: "qqmap://map/search?keyword=\(encodedQuery)&referer=YingQi")
        }
    }

    private func appleMapsURL(
        for booking: BookingRecord,
        query: String,
        coordinate: CLLocationCoordinate2D?
    ) -> URL {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let fallbackURL = URL(string: "https://maps.apple.com/?daddr=\(encodedQuery)&dirflg=d")
            ?? URL(fileURLWithPath: "/")

        if let coordinate {
            let encodedName = (booking.venue.isEmpty ? booking.title : booking.venue)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? booking.title
            return URL(
                string: "https://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d&name=\(encodedName)"
            ) ?? fallbackURL
        }

        return fallbackURL
    }

}

private struct NavigationMapSheet: View {
    @Environment(\.dismiss) private var dismiss

    let booking: BookingRecord
    let onChoose: (OverviewView.NavigationMapChoice) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(booking.title)
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)

                        Text("\(AppFormatters.shortDate(booking.startAt)) · \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))")
                            .font(AppTypography.meta)
                            .foregroundStyle(AppTheme.secondaryInk)

                        Text(booking.fullAddressText.isEmpty ? "请先补充地点信息" : booking.fullAddressText)
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                } header: {
                    Text("当前档期")
                }

                Section("选择地图") {
                    ForEach(OverviewView.NavigationMapChoice.allCases) { choice in
                        Button {
                            dismiss()
                            onChoose(choice)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: choice.symbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(choice == .apple ? "\(choice.title)（默认）" : choice.title)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(choice == .apple ? "系统地图，优先打开" : "若已安装，将直接跳转")
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("一键导航")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct BookingReminderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let booking: BookingRecord
    let client: ClientRecord?
    let monthBookings: [BookingRecord]
    let onContact: () -> Void
    let onNavigate: () -> Void

    private let calendar = Calendar.current

    private var monthDates: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: booking.startAt)),
              let dayRange = calendar.range(of: .day, in: .month, for: booking.startAt)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dates: [Date?] = Array(repeating: nil, count: leadingDays)

        for day in dayRange {
            dates.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }

        while dates.count % 7 != 0 {
            dates.append(nil)
        }

        return dates
    }

    private var weekdaySymbols: [String] {
        AppFormatters.reorderedShortWeekdaySymbols(firstWeekday: calendar.firstWeekday)
    }

    private var bookingDay: Date {
        calendar.startOfDay(for: booking.startAt)
    }

    private var monthBookingCount: Int {
        monthBookings.filter { calendar.isDate($0.startAt, equalTo: booking.startAt, toGranularity: .month) }.count
    }

    private var bookedDaysCount: Int {
        Set(monthBookings.map { calendar.startOfDay(for: $0.startAt) }).count
    }

    private var peakDayCount: Int {
        monthBookings.reduce(into: [:]) { counts, item in
            let day = calendar.startOfDay(for: item.startAt)
            counts[day, default: 0] += 1
        }
        .values
        .max() ?? 0
    }

    private var monthGridRows: [[Date?]] {
        stride(from: 0, to: monthDates.count, by: 7).map { start in
            Array(monthDates[start..<min(start + 7, monthDates.count)])
        }
    }

    private var monthDensityRows: [(label: String, count: Int)] {
        monthGridRows.enumerated().map { index, row in
            let rowCount = row.compactMap { $0 }.reduce(0) { total, date in
                total + bookings(on: date).count
            }
            return ("第\(index + 1)周", rowCount)
        }
    }

    private var bookingSheetBackdrop: some View {
        ZStack {
            Color(red: 0.985, green: 0.986, blue: 0.982)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color(red: 0.98, green: 0.99, blue: 0.985),
                    Color(red: 0.96, green: 0.97, blue: 0.965)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.64),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 360
            )
            .blendMode(.screen)
        }
    }

    private var monthDensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当月档期密度")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(bookedDaysCount) 天 / \(monthBookingCount) 场")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(monthDensityRows.enumerated()), id: \.offset) { _, row in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(AppTheme.line.opacity(0.34))
                                .frame(height: 72)

                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.84, green: 0.97, blue: 0.74),
                                            AppTheme.success
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(8, 72 * CGFloat(row.count) / CGFloat(max(monthDensityRows.map(\.count).max() ?? 1, 1))))
                        }

                        VStack(spacing: 2) {
                            Text(row.label)
                                .font(AppTypography.meta)
                                .foregroundStyle(AppTheme.mutedInk)
                            Text("\(row.count)")
                                .font(AppTypography.meta.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 8) {
                Text("峰值 \(peakDayCount) 场")
                Text("·")
                Text("密度 \(Int((Double(bookedDaysCount) / Double(max(Calendar.current.range(of: .day, in: .month, for: booking.startAt)?.count ?? 1, 1))) * 100))%")
            }
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(16)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.58), lineWidth: 1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("拍摄月视图")
                            .font(AppTypography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text(booking.title)
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppTheme.ink)

                        Text("\(AppFormatters.countdownText(to: booking.startAt)) · \(AppFormatters.shortDate(booking.startAt))")
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("客户")
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.mutedInk)
                                Text(client?.name ?? "未绑定客户")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("地点")
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.mutedInk)
                                Text("\(booking.city) \(booking.venue)")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppTheme.ink)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        HStack {
                            Text(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("\(monthBookingCount) 场")
                                .font(AppTypography.meta.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.58), lineWidth: 1)
                    }

                    monthDensitySection

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(AppFormatters.monthYear(booking.startAt))
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("月视图")
                                .font(AppTypography.meta.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.mutedInk)
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    dayCell(date)
                                } else {
                                    Color.clear
                                        .frame(height: 50)
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            onContact()
                        } label: {
                            Label("联系客户", systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())

                        Button {
                            onNavigate()
                        } label: {
                            Label("一键导航", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(bookingSheetBackdrop.ignoresSafeArea())
            .presentationBackground(Color(red: 0.985, green: 0.986, blue: 0.982))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isBookingDay = calendar.isDate(date, inSameDayAs: bookingDay)
        let dayBookings = bookings(on: date)

        return VStack(spacing: 5) {
            Text("\(calendar.component(.day, from: date))")
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(isBookingDay ? .white : AppTheme.ink)
                .frame(width: 36, height: 36)
                .background {
                    if isBookingDay {
                        Circle().fill(AppTheme.heroGradient)
                    } else if dayBookings.isEmpty == false {
                        Circle().fill(AppTheme.accent.opacity(0.12))
                    }
                }

            HStack(spacing: 3) {
                ForEach(0..<min(dayBookings.count, 3), id: \.self) { _ in
                    Circle()
                        .fill(isBookingDay ? Color.white : AppTheme.accent)
                        .frame(width: 4, height: 4)
                }

                if dayBookings.count > 3 {
                    Text("+")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isBookingDay ? .white : AppTheme.accent)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
    }

    private func bookings(on date: Date) -> [BookingRecord] {
        monthBookings.filter { calendar.isDate($0.startAt, inSameDayAs: date) }
    }
}
