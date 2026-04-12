import MapKit
import SwiftUI
import UIKit

private struct BookingClientRoute: Hashable {
    let clientID: UUID
}

private enum NavigationTransport: String, CaseIterable, Identifiable {
    case driving
    case walking
    case transit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: "驾车"
        case .walking: "步行"
        case .transit: "公交"
        }
    }

    var mapKitMode: String {
        switch self {
        case .driving: MKLaunchOptionsDirectionsModeDriving
        case .walking: MKLaunchOptionsDirectionsModeWalking
        case .transit: MKLaunchOptionsDirectionsModeTransit
        }
    }

    var symbolName: String {
        switch self {
        case .driving: "car.fill"
        case .walking: "figure.walk"
        case .transit: "tram.fill"
        }
    }
}

struct BookingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    let bookingID: UUID

    @State private var editingBooking: BookingRecord?
    @State private var duplicatingBooking: BookingRecord?
    @State private var shareItems: [Any] = []
    @State private var selectedTransport: NavigationTransport = .driving
    @State private var navigationErrorMessage: String?
    @State private var copiedMessage: String?
    @State private var contactErrorMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var showingPaymentSheet = false
    @State private var editingPayment: PaymentRecord?
    @State private var paymentPendingDeletion: PaymentRecord?
    @State private var showingTouchpointSheet = false
    @State private var businessCenterRoute: BusinessCenterRoute?
    @State private var businessToolsExpanded = false

    private let calendar = Calendar.current

    private var booking: BookingRecord? {
        store.booking(id: bookingID)
    }

    private var bookingClient: ClientRecord? {
        guard let booking else { return nil }
        return store.client(for: booking)
    }

    private var currentCrewMemberName: String? {
        store.preferredCrewMemberName
    }

    private var phoneURL: URL? {
        guard let phone = bookingClient?.phoneNumber else { return nil }
        let digits = AppFormatters.sanitizedPhoneNumber(phone)
        guard digits.isEmpty == false else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private var relatedTouchpoints: [TouchpointRecord] {
        store.touchpoints
            .filter { $0.bookingID == bookingID && $0.isArchived == false }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var sameDayBookings: [BookingRecord] {
        guard let booking else { return [] }
        return store.bookings(on: booking.startAt, calendar: calendar)
    }

    private var personalAssignments: [BookingCrewAssignment] {
        guard let booking else { return [] }
        return store.assignments(for: booking, matching: currentCrewMemberName)
    }

    private var teammateAssignments: [BookingCrewAssignment] {
        guard let booking else { return [] }
        return store.otherAssignments(for: booking, excluding: currentCrewMemberName)
    }

    private var mySameDayBookings: [BookingRecord] {
        guard let booking, let memberName = currentCrewMemberName else { return [] }
        return store.bookings(on: booking.startAt, assignedTo: memberName, calendar: calendar)
    }

    private var overlappingMyBookings: [(BookingRecord, BookingRecord)] {
        guard mySameDayBookings.count > 1 else { return [] }
        var pairs: [(BookingRecord, BookingRecord)] = []
        for lhsIndex in mySameDayBookings.indices {
            for rhsIndex in mySameDayBookings.indices where rhsIndex > lhsIndex {
                let lhs = mySameDayBookings[lhsIndex]
                let rhs = mySameDayBookings[rhsIndex]
                if lhs.startAt < rhs.endAt && rhs.startAt < lhs.endAt {
                    pairs.append((lhs, rhs))
                }
            }
        }
        return pairs
    }

    var body: some View {
        Group {
            if let booking {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        heroSummaryCard(booking)
                        primaryActionBar(booking)
                        executionOverviewSection(booking)
                        clientSection(booking)
                        personalFocusSection(booking)
                        paymentSection(booking)
                        deliveryNotesSection(booking)
                        touchpointsSection(booking)
                        crewBoardSection(booking)
                        dailyDispatchSection(booking)
                        businessCenterSection(booking)
                        operationSection(booking)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
                .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button("编辑", systemImage: "square.and.pencil") {
                            editingBooking = booking
                        }
                        Button("分享", systemImage: "square.and.arrow.up") {
                            prepareShare(for: booking)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "订单不存在",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("该项目可能已被删除。")
                )
            }
        }
        .navigationTitle("订单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBooking) { booking in
            BookingEditorView(booking: booking)
        }
        .sheet(item: $duplicatingBooking) { booking in
            BookingEditorView(booking: booking)
        }
        .sheet(isPresented: $showingPaymentSheet) {
            if let booking {
                BookingPaymentSheet(
                    booking: booking,
                    outstandingAmount: store.outstandingAmount(for: booking)
                )
                .environment(store)
            }
        }
        .sheet(item: $editingPayment) { payment in
            if let booking {
                BookingPaymentSheet(
                    booking: booking,
                    outstandingAmount: store.outstandingAmount(for: booking),
                    existingPayment: payment
                )
                .environment(store)
            }
        }
        .sheet(isPresented: $showingTouchpointSheet) {
            if let booking {
                TouchpointEditorView(prefilledClient: bookingClient, prefilledBooking: booking)
                    .environment(store)
            }
        }
        .sheet(item: $businessCenterRoute) { route in
            BusinessCenterView(
                initialMode: route.mode,
                bookingID: route.bookingID,
                clientID: route.clientID
            )
            .environment(store)
        }
        .navigationDestination(for: BookingClientRoute.self) { route in
            ClientDetailView(clientID: route.clientID)
        }
        .sheet(isPresented: Binding(
            get: { shareItems.isEmpty == false },
            set: { presented in if presented == false { shareItems = [] } }
        )) {
            BookingActivityView(activityItems: shareItems)
        }
        .alert("无法开始导航", isPresented: Binding(
            get: { navigationErrorMessage != nil },
            set: { if $0 == false { navigationErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(navigationErrorMessage ?? "")
        }
        .alert("联系失败", isPresented: Binding(
            get: { contactErrorMessage != nil },
            set: { if $0 == false { contactErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(contactErrorMessage ?? "")
        }
        .alert("提示", isPresented: Binding(
            get: { copiedMessage != nil },
            set: { if $0 == false { copiedMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(copiedMessage ?? "")
        }
        .confirmationDialog("确认删除这条付款流水？", isPresented: Binding(
            get: { paymentPendingDeletion != nil },
            set: { if $0 == false { paymentPendingDeletion = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let paymentPendingDeletion {
                    store.deletePayment(paymentPendingDeletion.id)
                    self.paymentPendingDeletion = nil
                    AppHaptics.success()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后该笔金额会从订单实收中扣除。")
        }
        .confirmationDialog("确认归档这个订单？", isPresented: $showingArchiveConfirmation) {
            Button("归档", role: .destructive) {
                store.archiveBooking(bookingID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("归档后订单会从主列表移到归档列表，可随时恢复。")
        }
        .confirmationDialog("确认删除这个订单？", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                store.deleteBooking(bookingID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后订单与付款流水将一并移除，且无法恢复。")
        }
    }

    private func prepareShare(for booking: BookingRecord) {
        let shareView = BookingShareCardView(
            booking: booking,
            client: bookingClient,
            studioProfile: store.resolvedStudioProfile,
            settings: store.settings,
            receivedAmount: store.receivedAmount(for: booking),
            outstandingAmount: store.outstandingAmount(for: booking)
        )
        .padding(20)
        .background(AppTheme.backgroundGradient)

        let renderer = ImageRenderer(content: shareView)
        renderer.scale = UIScreen.main.scale

        var items: [Any] = [
            BookingShareTextBuilder.text(
                for: booking,
                client: bookingClient,
                studioProfile: store.resolvedStudioProfile,
                settings: store.settings,
                receivedAmount: store.receivedAmount(for: booking),
                outstandingAmount: store.outstandingAmount(for: booking)
            )
        ]
        if let image = renderer.uiImage {
            items.insert(image, at: 0)
        }
        shareItems = items
        AppHaptics.success()
    }

    private func heroSummaryCard(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bookingClient?.name ?? "未绑定客户")
                        .font(AppTypography.heroTitle)
                        .foregroundStyle(.white)
                    Text(booking.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    BookingStatusBadge(status: booking.status)
                    PaymentStatusBadge(status: store.paymentStatus(for: booking))
                }
            }

            HStack(spacing: 8) {
                heroTag(AppFormatters.shortMonthDay(booking.startAt))
                heroTag(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                heroTag(booking.category.title)
            }

            Text(booking.fullAddressText.isEmpty ? "地点待补充" : booking.fullAddressText)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                heroMetric(title: "总价", value: AppFormatters.currency(booking.fee))
                heroMetric(title: "已收", value: AppFormatters.currency(store.receivedAmount(for: booking)))
                heroMetric(
                    title: sameDayBookings.count > 1 ? "同日" : "团队",
                    value: sameDayBookings.count > 1 ? "\(sameDayBookings.count) 场" : (booking.crewAssignments.isEmpty ? "待排" : "\(booking.crewAssignments.count) 人")
                )
            }

            if let personalHeadline = personalAssignmentHeadline(for: booking) {
                heroNote(systemImage: "person.crop.circle.badge.checkmark", text: personalHeadline)
            }

            if let memberName = currentCrewMemberName, mySameDayBookings.count > 1 {
                heroNote(systemImage: "calendar.badge.clock", text: "\(memberName) 当天共负责 \(mySameDayBookings.count) 场，下面会继续拆出我负责与团队其他。")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepShadow.opacity(0.18), radius: AppShadow.heroRadius, y: AppShadow.heroY)
    }

    private func primaryActionBar(_ booking: BookingRecord) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(NavigationTransport.allCases) { transport in
                        Button {
                            selectedTransport = transport
                            openInMaps(booking)
                        } label: {
                            Label("\(transport.title)导航", systemImage: transport.symbolName)
                        }
                    }
                } label: {
                    Label("导航", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(booking.navigationQueryText.isEmpty)

                Button {
                    contactClient()
                } label: {
                    Label("联系客户", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            Button {
                prepareShare(for: booking)
            } label: {
                Label("分享订单确认单", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
    }

    private func executionOverviewSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: "执行总览") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewTile(title: "日期", value: AppFormatters.shortDate(booking.startAt), subtitle: AppFormatters.weekday(booking.startAt))
                overviewTile(title: "时段", value: AppFormatters.timeRange(start: booking.startAt, end: booking.endAt), subtitle: durationText(for: booking))
                overviewTile(title: "场地", value: booking.venue.isEmpty ? "待补充" : booking.venue, subtitle: booking.city.isEmpty ? nil : booking.city)
                overviewTile(title: "交付", value: booking.deliverableText.isEmpty ? "待补充" : booking.deliverableText, subtitle: booking.locationNote.isEmpty ? nil : "到场提示：\(booking.locationNote)")
            }

            if let memberName = currentCrewMemberName {
                AppInlineNote(systemImage: "person.crop.circle.fill", text: "当前成员：\(memberName)")
            } else {
                AppInlineNote(systemImage: "person.crop.circle.badge.questionmark", text: "在设置里填成员名后，这里会自动高亮“我负责”。")
            }

            if booking.addressText.isEmpty == false {
                AppInlineNote(systemImage: "mappin.and.ellipse", text: booking.addressText)
            }
        }
    }

    private func personalFocusSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: personalSectionTitle, subtitle: personalSectionSubtitle(for: booking)) {
            if booking.crewAssignments.isEmpty {
                AppInlineNote(systemImage: "person.3.sequence.fill", text: "还没有录入成员分工，建议把主拍、副拍、摄像和统筹拆开记录。")
            } else if currentCrewMemberName == nil {
                VStack(alignment: .leading, spacing: 12) {
                    AppInlineNote(systemImage: "person.crop.circle.badge.questionmark", text: "未选择当前成员")
                    if let firstAssignment = booking.crewAssignments.first {
                        assignmentCard(firstAssignment, highlight: false)
                    }
                }
            } else if personalAssignments.isEmpty {
                AppInlineNote(systemImage: "person.crop.circle.badge.exclamationmark", text: "当前成员没有被分到这单。")
            } else {
                VStack(spacing: 12) {
                    ForEach(personalAssignments) { assignment in
                        assignmentCard(assignment, highlight: true)
                    }
                }

                if mySameDayBookings.count > 1 {
                    AppInlineNote(
                        systemImage: overlappingMyBookings.isEmpty ? "calendar.badge.clock" : "exclamationmark.triangle.fill",
                        text: overlappingMyBookings.isEmpty
                            ? "当天你共负责 \(mySameDayBookings.count) 场，下面会继续列出你当天其他场次。"
                            : "当天你的排班有重叠，建议尽快调整成员分工。",
                        tint: overlappingMyBookings.isEmpty ? AppTheme.secondaryInk : AppTheme.warning
                    )
                }
            }
        }
    }

    private func dailyDispatchSection(_ booking: BookingRecord) -> some View {
        let mine = currentCrewMemberName == nil ? [] : mySameDayBookings
        let mineIDs = Set(mine.map(\.id))
        let teamOthers = sameDayBookings.filter { mineIDs.contains($0.id) == false }

        return GlassCard(title: "团队排班", subtitle: dispatchSubtitle) {
            if sameDayBookings.isEmpty {
                AppInlineNote(systemImage: "calendar", text: "当天还没有其他订单。")
            } else {
                if let memberName = currentCrewMemberName, memberName.isEmpty == false {
                    AppInlineNote(
                        systemImage: "person.2.fill",
                        text: mine.isEmpty ? "\(memberName) 当天没有被分到场次。" : "\(memberName) 当天负责 \(mine.count) 场。",
                        tint: AppTheme.secondaryInk
                    )
                }

                if overlappingMyBookings.isEmpty == false {
                    AppInlineNote(
                        systemImage: "exclamationmark.triangle.fill",
                        text: overlappingMyBookings.map { "\($0.0.title) ↔ \($0.1.title)" }.joined(separator: "、"),
                        tint: AppTheme.warning
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    if currentCrewMemberName != nil {
                        if mine.isEmpty == false {
                            dispatchGroup(title: "我的安排", subtitle: "", bookings: mine, currentBookingID: booking.id)
                        }
                        if teamOthers.isEmpty == false {
                            dispatchGroup(title: "团队其他安排", subtitle: "", bookings: teamOthers, currentBookingID: booking.id)
                        }
                    } else {
                        dispatchGroup(title: "团队其他安排", subtitle: "未选择当前成员", bookings: sameDayBookings, currentBookingID: booking.id)
                    }
                }
            }
        }
    }

    private func crewBoardSection(_ booking: BookingRecord) -> some View {
        let members = currentCrewMemberName == nil ? BookingCrewAssignment.normalized(booking.crewAssignments) : teammateAssignments

        return GlassCard(
            title: "团队其他安排",
            subtitle: members.isEmpty ? nil : "看清每个人去哪场、做什么。"
        ) {
            if members.isEmpty {
                AppInlineNote(systemImage: "person.3.sequence.fill", text: "除当前成员外，暂时没有其他分工。")
            } else {
                VStack(spacing: 10) {
                    ForEach(members) { assignment in
                        assignmentCard(assignment, highlight: false)
                    }
                }
            }
        }
    }

    private func paymentSection(_ booking: BookingRecord) -> some View {
        let receivedAmount = store.receivedAmount(for: booking)
        let outstandingAmount = store.outstandingAmount(for: booking)
        let paymentRecords = store.payments(for: booking.id)

        return GlassCard(title: "费用状态") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AppMetricTile(title: "总价", value: AppFormatters.currency(booking.fee), fillColor: AppTheme.panelStrong)
                AppMetricTile(title: "已收", value: AppFormatters.currency(receivedAmount), fillColor: AppTheme.panelStrong)
                AppMetricTile(title: "待收", value: AppFormatters.currency(outstandingAmount), fillColor: AppTheme.panelStrong)
            }

            HStack(spacing: 12) {
                PaymentStatusBadge(status: store.paymentStatus(for: booking))
                Spacer()
                Button {
                    showingPaymentSheet = true
                } label: {
                    Label("记录 / 编辑回款", systemImage: "creditcard")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .frame(maxWidth: 196)
            }

            if paymentRecords.isEmpty {
                AppInlineNote(systemImage: "banknote", text: "还没有付款流水。")
            } else {
                VStack(spacing: 10) {
                    ForEach(paymentRecords) { payment in
                        paymentRow(payment)
                    }
                }
            }
        }
    }

    private func businessCenterSection(_ booking: BookingRecord) -> some View {
        let summary = store.businessSummary(for: booking.id, clientID: booking.clientID)
        let systemStatus = store.calendarLink(for: booking.id, provider: .system)?.status.title ?? "未启用"
        let googleStatus = store.calendarLink(for: booking.id, provider: .google)?.status.title ?? (store.googleCalendarConnection.accountEmail.isEmpty ? "未配置" : "已记录账号")

        return GlassCard(title: "业务协同") {
            AppKeyValueRow(title: "系统日历整备", value: systemStatus)
            AppKeyValueRow(title: "Google 接入", value: googleStatus)
            AppInlineNote(systemImage: "doc.text.magnifyingglass", text: "文档 \(summary.documents) 份 · 资料 \(summary.attachments) 份")

            DisclosureGroup(isExpanded: $businessToolsExpanded) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        bookingBusinessButton(mode: .workflow, subtitle: "报价到开票闭环", booking: booking)
                        bookingBusinessButton(mode: .calendar, subtitle: "接入准备", booking: booking)
                    }
                    HStack(spacing: 10) {
                        bookingBusinessButton(mode: .assets, subtitle: "资料与附件", booking: booking)
                        bookingBusinessButton(mode: .collaboration, subtitle: "团队权限与留痕", booking: booking)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Text("展开业务工具")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("合同、日历、资料、协作")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
    }

    private func bookingBusinessButton(mode: BusinessCenterMode, subtitle: String, booking: BookingRecord) -> some View {
        Button {
            businessCenterRoute = BusinessCenterRoute(mode: mode, bookingID: booking.id, clientID: booking.clientID)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(mode.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                }
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .appCardSurface(fillColor: AppTheme.panelStrong)
        }
        .buttonStyle(.plain)
    }

    private func deliveryNotesSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: "交付与补充") {
            if booking.deliverableText.isEmpty && booking.notesText.isEmpty && booking.locationNote.isEmpty {
                AppInlineNote(systemImage: "text.bubble", text: "暂未补充备注。")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if booking.deliverableText.isEmpty == false {
                        detailBlock(title: "交付内容", value: booking.deliverableText)
                    }
                    if booking.notesText.isEmpty == false {
                        detailBlock(title: "执行备注", value: booking.notesText)
                    }
                    if booking.locationNote.isEmpty == false {
                        detailBlock(title: "到场提示", value: booking.locationNote)
                    }
                }
            }
        }
    }

    private func clientSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: "关联客户") {
            if let bookingClient {
                NavigationLink(value: BookingClientRoute(clientID: bookingClient.id)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bookingClient.name)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                            Text([bookingClient.city, bookingClient.preferredContactText].filter { $0.isEmpty == false }.joined(separator: " · "))
                                .font(AppTypography.meta)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            } else {
                AppInlineNote(systemImage: "person.crop.circle.badge.xmark", text: "当前订单没有绑定客户。")
            }
        }
    }

    private func touchpointsSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: "关联跟进", subtitle: relatedTouchpoints.isEmpty ? nil : "共 \(relatedTouchpoints.count) 条") {
            if relatedTouchpoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AppInlineNote(systemImage: "checklist", text: "还没有关联跟进。")
                    Button {
                        showingTouchpointSheet = true
                    } label: {
                        Label("新建跟进", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(relatedTouchpoints) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(AppFormatters.dayAndTime(item.dueAt))
                                        .font(AppTypography.meta)
                                        .foregroundStyle(AppTheme.mutedInk)
                                    if item.detailsText.isEmpty == false {
                                        Text(item.detailsText)
                                            .font(AppTypography.meta)
                                            .foregroundStyle(AppTheme.secondaryInk)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                PriorityBadge(priority: item.priority)
                            }

                            HStack(spacing: 10) {
                                Label(item.channel.title, systemImage: item.channel.symbolName)
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.mutedInk)
                                Spacer()
                                Text(item.isComplete ? "已完成" : AppFormatters.relativeDueText(item.dueAt, calendar: calendar))
                                    .font(AppTypography.meta)
                                    .foregroundStyle(item.isComplete ? AppTheme.success : AppTheme.warning)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    private func operationSection(_ booking: BookingRecord) -> some View {
        GlassCard(title: "订单操作") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                actionTile(title: "编辑", systemImage: "square.and.pencil", tint: AppTheme.accent) {
                    editingBooking = booking
                }
                actionTile(title: "复制档期", systemImage: "plus.square.on.square", tint: AppTheme.info) {
                    duplicatingBooking = duplicatedBooking(from: booking)
                }
                actionTile(title: "新建跟进", systemImage: "checklist.checked", tint: AppTheme.accentWarmDeep) {
                    showingTouchpointSheet = true
                }
                actionTile(title: booking.status == .delivered ? "已完成" : "标记完成", systemImage: "checkmark.circle.fill", tint: AppTheme.success) {
                    guard booking.status != .delivered else { return }
                    var updated = booking
                    updated.status = .delivered
                    store.upsert(booking: updated)
                }
                actionTile(title: "归档", systemImage: "archivebox", tint: AppTheme.secondaryInk) {
                    showingArchiveConfirmation = true
                }
                actionTile(title: "删除", systemImage: "trash", tint: AppTheme.danger) {
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    private var personalSectionTitle: String {
        if let memberName = currentCrewMemberName, memberName.isEmpty == false {
            return "我负责什么"
        }
        return "我负责什么"
    }

    private func personalSectionSubtitle(for booking: BookingRecord) -> String? {
        guard booking.crewAssignments.isEmpty == false else { return nil }
        if personalAssignments.isEmpty == false {
            return "先看自己负责什么，再看团队如何协同。"
        }
        return nil
    }

    private var dispatchSubtitle: String {
        let totalCount = sameDayBookings.count
        if let memberName = currentCrewMemberName, memberName.isEmpty == false {
            let mine = mySameDayBookings.count
            if mine > 0 {
                return "当天共 \(totalCount) 场，\(memberName) 负责 \(mine) 场。"
            }
            return "当天共 \(totalCount) 场，\(memberName) 暂未被分配。"
        }
        return "当天共 \(totalCount) 场，按成员查看谁去哪场。"
    }

    private func heroTag(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func heroNote(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
            Text(text)
                .font(AppTypography.meta)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewTile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
        }
    }

    private func assignmentCard(_ assignment: BookingCrewAssignment, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: assignment.role.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(highlight ? AppTheme.accentWarmDeep : AppTheme.accent)
                    .frame(width: 30, height: 30)
                    .background((highlight ? AppTheme.accentSurface : AppTheme.panelSoft), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.headlineText)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text(assignment.operationalSummaryText)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if highlight {
                    Text("我负责")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentSurface, in: Capsule())
                }
            }

            if let note = assignment.noteSummaryText {
                AppInlineNote(systemImage: "note.text", text: note)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(highlight ? AppTheme.accentSoft.opacity(0.9) : AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((highlight ? AppTheme.accent.opacity(0.22) : AppTheme.line.opacity(0.72)), lineWidth: 1)
        }
    }

    private func dailyDispatchCard(_ item: BookingRecord, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFormatters.timeRange(start: item.startAt, end: item.endAt))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text(store.clientName(for: item))
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Spacer(minLength: 12)

                if isCurrent {
                    Text("当前订单")
                        .font(AppTypography.badge)
                        .foregroundStyle(AppTheme.accentWarmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentSurface, in: Capsule())
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }

            Text(item.title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.venue.isEmpty ? item.fullAddressText : item.venue)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)

            if let memberName = currentCrewMemberName {
                let mine = store.assignments(for: item, matching: memberName)
                if mine.isEmpty == false {
                    AppInlineNote(systemImage: "person.crop.circle.badge.checkmark", text: mine.map(\.operationalSummaryText).joined(separator: " / "), tint: AppTheme.accentWarmDeep)
                } else if item.crewAssignments.isEmpty == false {
                    AppInlineNote(systemImage: "person.3.fill", text: BookingShareTextBuilder.crewAssignmentSummary(for: item))
                }
            } else if item.crewAssignments.isEmpty == false {
                AppInlineNote(systemImage: "person.3.fill", text: BookingShareTextBuilder.crewAssignmentSummary(for: item))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? AppTheme.accentSoft.opacity(0.82) : AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((isCurrent ? AppTheme.accent.opacity(0.22) : AppTheme.line.opacity(0.72)), lineWidth: 1)
        }
    }

    private func dispatchGroup(title: String, subtitle: String, bookings: [BookingRecord], currentBookingID: UUID) -> some View {
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

            Text(subtitle)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)

            VStack(spacing: 10) {
                ForEach(bookings) { item in
                    if item.id == currentBookingID {
                        dailyDispatchCard(item, isCurrent: true)
                    } else {
                        NavigationLink {
                            BookingDetailView(bookingID: item.id)
                        } label: {
                            dailyDispatchCard(item, isCurrent: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func paymentRow(_ payment: PaymentRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentType.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                Text(AppFormatters.dayAndTime(payment.date))
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.mutedInk)
                if payment.note.isEmpty == false {
                    Text(payment.note)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(AppFormatters.currency(payment.amount))
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)

                Menu {
                    Button("编辑") {
                        editingPayment = payment
                    }
                    Button("删除", role: .destructive) {
                        paymentPendingDeletion = payment
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
        }
    }

    private func detailBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionTile(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func durationText(for booking: BookingRecord) -> String {
        let interval = max(booking.endAt.timeIntervalSince(booking.startAt), 0)
        let hours = interval / 3600
        if hours >= 1 {
            return String(format: "%.1f 小时", hours)
        }
        return "短时段"
    }

    private func personalAssignmentHeadline(for booking: BookingRecord) -> String? {
        guard personalAssignments.isEmpty == false else { return nil }
        return personalAssignments.map { $0.role.title + " · " + $0.operationalSummaryText }.joined(separator: " / ")
    }

    private func duplicatedBooking(from booking: BookingRecord) -> BookingRecord {
        let startAt = Calendar.current.date(byAdding: .day, value: 7, to: booking.startAt) ?? booking.startAt
        let endAt = Calendar.current.date(byAdding: .day, value: 7, to: booking.endAt) ?? booking.endAt
        return BookingRecord(
            id: UUID(),
            title: booking.title,
            category: booking.category,
            status: .tentative,
            startAt: startAt,
            endAt: endAt,
            venue: booking.venue,
            city: booking.city,
            addressText: booking.addressText,
            locationNote: booking.locationNote,
            latitude: booking.latitude,
            longitude: booking.longitude,
            fee: booking.fee,
            depositPaid: 0,
            deliverableText: booking.deliverableText,
            notesText: booking.notesText,
            shootingAttributes: booking.shootingAttributes,
            crewAssignments: booking.crewAssignments,
            reminderOffsets: booking.reminderOffsets,
            createdAt: .now,
            clientID: booking.clientID
        )
    }

    private func contactClient() {
        guard let phoneURL else {
            contactErrorMessage = "客户还没有填写可用的联系电话。"
            AppHaptics.error()
            return
        }
        AppHaptics.impactMedium()
        UIApplication.shared.open(phoneURL)
    }

    private func openInMaps(_ booking: BookingRecord) {
        let query = booking.navigationQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            navigationErrorMessage = "先在订单里补充场地或详细地址，才能开始导航。"
            AppHaptics.error()
            return
        }

        if let coordinate = booking.coordinate {
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            destination.name = booking.venue.isEmpty ? booking.title : booking.venue
            let options: [String: Any] = [
                MKLaunchOptionsDirectionsModeKey: selectedTransport.mapKitMode,
                MKLaunchOptionsShowsTrafficKey: true
            ]
            destination.openInMaps(launchOptions: options)
            return
        }

        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=\(transportFlag)") {
            AppHaptics.impactMedium()
            UIApplication.shared.open(url)
        } else {
            navigationErrorMessage = "当前无法生成可用的导航地址，请先回到编辑页补全详细地址。"
            AppHaptics.error()
        }
    }

    private var transportFlag: String {
        switch selectedTransport {
        case .driving: "d"
        case .walking: "w"
        case .transit: "r"
        }
    }
}

private struct BookingPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    let booking: BookingRecord
    let outstandingAmount: Double
    let existingPayment: PaymentRecord?

    @State private var amount: Double
    @State private var paymentType: PaymentType
    @State private var date: Date
    @State private var note: String

    init(booking: BookingRecord, outstandingAmount: Double, existingPayment: PaymentRecord? = nil) {
        self.booking = booking
        self.outstandingAmount = outstandingAmount
        self.existingPayment = existingPayment
        _amount = State(initialValue: existingPayment?.amount ?? outstandingAmount)
        _paymentType = State(initialValue: existingPayment?.paymentType ?? .deposit)
        _date = State(initialValue: existingPayment?.date ?? .now)
        _note = State(initialValue: existingPayment?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("付款信息") {
                    Picker("类型", selection: $paymentType) {
                        ForEach(PaymentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("金额", value: $amount, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.decimalPad)
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(existingPayment == nil ? "更新回款" : "编辑回款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let payment = PaymentRecord(
                            id: existingPayment?.id ?? UUID(),
                            bookingID: booking.id,
                            amount: max(amount, 0),
                            paymentType: paymentType,
                            date: date,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: existingPayment?.createdAt ?? .now
                        )
                        store.upsert(payment: payment)
                        AppHaptics.success()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

private struct BookingActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct BookingShareCardView: View {
    let booking: BookingRecord
    let client: ClientRecord?
    let studioProfile: StudioProfile
    let settings: AppSettings
    let receivedAmount: Double
    let outstandingAmount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(studioProfile.displayName.isEmpty ? "影期" : studioProfile.displayName)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                Spacer()
                Text("拍摄确认单")
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(booking.title)
                    .font(AppTypography.heroTitle)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 8) {
                    BookingStatusBadge(status: booking.status)
                    ServiceCategoryBadge(category: booking.category)
                }
            }

            VStack(spacing: 12) {
                shareRow("客户", client?.name ?? "未绑定客户")
                shareRow("日期", AppFormatters.shortDate(booking.startAt))
                shareRow("时段", AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))
                shareRow("地点", booking.fullAddressText)
                if booking.addressText.isEmpty == false {
                    shareRow("详细地址", booking.addressText)
                }
                if booking.locationNote.isEmpty == false {
                    shareRow("到场提示", booking.locationNote)
                }
                shareRow("报价", AppFormatters.currency(booking.fee))
                shareRow("已收金额", AppFormatters.currency(receivedAmount))
                shareRow("待回款", AppFormatters.currency(outstandingAmount))
                shareRow("结清规则", settings.defaultBalanceRule)
                shareRow("拍摄属性", ShootingAttribute.displayTitle(for: booking.shootingAttributes))
                shareRow("工作室分工", BookingShareTextBuilder.crewAssignmentSummary(for: booking))
                shareRow("交付", booking.deliverableText.isEmpty ? "待补充" : booking.deliverableText)
                if booking.notesText.isEmpty == false {
                    shareRow("备注", booking.notesText)
                }
            }

            Rectangle()
                .fill(AppTheme.line.opacity(0.5))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("影期为摄影师提供档期、客户、跟进与回款的统一管理。")
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                if studioProfile.legalName.isEmpty == false {
                    Text("签约主体：\(studioProfile.legalName)")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                if studioProfile.contactPhone.isEmpty == false {
                    Text("联系电话：\(studioProfile.contactPhone)")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                if studioProfile.contactEmail.isEmpty == false {
                    Text("联系邮箱：\(studioProfile.contactEmail)")
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                if footerAddressLine.isEmpty == false {
                    Text(footerAddressLine)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
        .padding(24)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(AppTheme.line.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow, radius: AppShadow.cardRadius, y: AppShadow.cardY)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerAddressLine: String {
        [studioProfile.city, studioProfile.address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }

    private func shareRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 16)
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

enum BookingShareTextBuilder {
    static func text(
        for booking: BookingRecord,
        client: ClientRecord?,
        studioProfile: StudioProfile,
        settings: AppSettings,
        receivedAmount: Double,
        outstandingAmount: Double
    ) -> String {
        let addressLine = [studioProfile.city, studioProfile.address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")

        return [
            "【\(booking.title)】拍摄确认单",
            studioProfile.displayName.isEmpty ? nil : "工作室：\(studioProfile.displayName)",
            studioProfile.legalName.isEmpty ? nil : "签约主体：\(studioProfile.legalName)",
            "客户：\(client?.name ?? "未绑定客户")",
            "日期：\(AppFormatters.shortDate(booking.startAt))",
            "时段：\(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))",
            "地点：\(booking.fullAddressText)",
            "报价：\(AppFormatters.currency(booking.fee))",
            "已收金额：\(AppFormatters.currency(receivedAmount))",
            "待回款：\(AppFormatters.currency(outstandingAmount))",
            "结清规则：\(settings.defaultBalanceRule)",
            "拍摄属性：\(ShootingAttribute.displayTitle(for: booking.shootingAttributes))",
            "工作室分工：\(crewAssignmentSummary(for: booking))",
            studioProfile.contactPhone.isEmpty ? nil : "联系电话：\(studioProfile.contactPhone)",
            studioProfile.contactEmail.isEmpty ? nil : "联系邮箱：\(studioProfile.contactEmail)",
            addressLine.isEmpty ? nil : "工作室地址：\(addressLine)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    static func crewAssignmentSummary(for booking: BookingRecord) -> String {
        let normalized = BookingCrewAssignment.normalized(booking.crewAssignments)
        guard normalized.isEmpty == false else { return "待安排" }

        let heads = normalized.prefix(2).map { "\($0.displayName)·\($0.role.title)" }
        if normalized.count > 2 {
            return heads.joined(separator: "、") + "、+\(normalized.count - 2)"
        }
        return heads.joined(separator: "、")
    }
}
