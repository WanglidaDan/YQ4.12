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
    @State private var selectedTransport: NavigationTransport = .driving
    @State private var showingPaymentSheet = false
    @State private var showingArchiveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var navigationErrorMessage: String?
    @State private var contactErrorMessage: String?

    private var booking: BookingRecord? {
        store.booking(id: bookingID)
    }

    private var bookingClient: ClientRecord? {
        guard let booking else { return nil }
        return store.client(for: booking)
    }

    private var phoneURL: URL? {
        guard let phone = bookingClient?.phoneNumber else { return nil }
        let digits = AppFormatters.sanitizedPhoneNumber(phone)
        guard digits.isEmpty == false else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var body: some View {
        Group {
            if let booking {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        heroSummary(booking)
                        orderInfoCard(booking)
                        financeCard(booking)
                        if booking.crewAssignments.isEmpty == false {
                            crewCard(booking)
                        }
                        if hasNotes(booking) {
                            notesCard(booking)
                        }
                        operationsCard(booking)
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
        .navigationDestination(for: BookingClientRoute.self) { route in
            ClientDetailView(clientID: route.clientID)
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

    private func heroSummary(_ booking: BookingRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if let bookingClient {
                        Text(bookingClient.name)
                            .font(AppTypography.heroTitle)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Text(booking.title)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(.white.opacity(0.92))
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

            let location = booking.fullAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
            if location.isEmpty == false {
                Text(location)
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepShadow.opacity(0.16), radius: AppShadow.heroRadius, y: AppShadow.heroY)
    }

    private func orderInfoCard(_ booking: BookingRecord) -> some View {
        detailCard(title: "订单信息") {
            VStack(spacing: 0) {
                if let bookingClient {
                    NavigationLink(value: BookingClientRoute(clientID: bookingClient.id)) {
                        plainInfoRow(
                            title: "客户",
                            value: bookingClient.name,
                            subtitle: [bookingClient.city, bookingClient.preferredContactText].filter { $0.isEmpty == false }.joined(separator: " · "),
                            trailing: "查看"
                        )
                    }
                    .buttonStyle(.plain)
                    thinDivider()
                }

                plainInfoRow(
                    title: "时间",
                    value: AppFormatters.shortDate(booking.startAt),
                    subtitle: "\(AppFormatters.weekday(booking.startAt)) · \(AppFormatters.timeRange(start: booking.startAt, end: booking.endAt))"
                )
                thinDivider()

                plainInfoRow(
                    title: "地点",
                    value: booking.venue.isEmpty ? "地点待补充" : booking.venue,
                    subtitle: booking.fullAddressText
                )
                thinDivider()

                plainInfoRow(
                    title: "类型",
                    value: booking.category.title,
                    subtitle: booking.status.title
                )
            }
        }
    }

    private func financeCard(_ booking: BookingRecord) -> some View {
        let receivedAmount = store.receivedAmount(for: booking)
        let outstandingAmount = store.outstandingAmount(for: booking)

        return detailCard(title: "费用") {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    flatAmount(title: "总价", value: AppFormatters.currency(booking.fee))
                    flatAmount(title: "已收", value: AppFormatters.currency(receivedAmount))
                    flatAmount(title: "待收", value: AppFormatters.currency(outstandingAmount), highlight: outstandingAmount > 0)
                }
                .padding(.vertical, 4)

                thinDivider()
                    .padding(.top, 12)

                Button {
                    showingPaymentSheet = true
                } label: {
                    HStack {
                        Text("记录 / 编辑回款")
                            .font(AppTypography.bodyStrong)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.ink)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func crewCard(_ booking: BookingRecord) -> some View {
        let assignments = BookingCrewAssignment.normalized(booking.crewAssignments)
        return detailCard(title: "团队分工") {
            VStack(spacing: 0) {
                ForEach(Array(assignments.enumerated()), id: \.element.id) { index, assignment in
                    VStack(spacing: 0) {
                        plainInfoRow(
                            title: assignment.role.title,
                            value: assignment.displayName,
                            subtitle: assignment.operationalSummaryText
                        )
                        if index < assignments.count - 1 {
                            thinDivider()
                        }
                    }
                }
            }
        }
    }

    private func notesCard(_ booking: BookingRecord) -> some View {
        detailCard(title: "备注") {
            VStack(spacing: 0) {
                var didAddRow = false

                if booking.deliverableText.isEmpty == false {
                    plainInfoRow(title: "交付", value: booking.deliverableText, subtitle: "")
                    didAddRow = true
                }

                if booking.notesText.isEmpty == false {
                    if didAddRow { thinDivider() }
                    plainInfoRow(title: "执行", value: booking.notesText, subtitle: "")
                    didAddRow = true
                }

                if booking.locationNote.isEmpty == false {
                    if didAddRow { thinDivider() }
                    plainInfoRow(title: "到场", value: booking.locationNote, subtitle: "")
                }
            }
        }
    }

    private func operationsCard(_ booking: BookingRecord) -> some View {
        detailCard(title: "操作") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        editingBooking = booking
                    } label: {
                        Label("编辑", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

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
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(booking.navigationQueryText.isEmpty)
                }

                HStack(spacing: 12) {
                    Button {
                        contactClient()
                    } label: {
                        Label("联系", systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(phoneURL == nil)

                    Button {
                        duplicatingBooking = duplicatedBooking(from: booking)
                    } label: {
                        Label("复制", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.top, 12)

                thinDivider()
                    .padding(.vertical, 14)

                HStack(spacing: 12) {
                    Button {
                        showingArchiveConfirmation = true
                    } label: {
                        Label("归档", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
    }

    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppTheme.ink)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel, strokeOpacity: 0.82)
    }

    private func plainInfoRow(title: String, value: String, subtitle: String, trailing: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(value.isEmpty ? "—" : value)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 12)
    }

    private func flatAmount(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(highlight ? AppTheme.accentWarmDeep : AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func thinDivider() -> some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.58))
    }

    private func heroTag(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func hasNotes(_ booking: BookingRecord) -> Bool {
        booking.deliverableText.isEmpty == false ||
        booking.notesText.isEmpty == false ||
        booking.locationNote.isEmpty == false
    }

    private func duplicatedBooking(from booking: BookingRecord) -> BookingRecord {
        var duplicate = booking
        duplicate.id = UUID()
        duplicate.createdAt = .now
        duplicate.updatedAt = .now
        duplicate.title = booking.title + " 副本"
        return duplicate
    }

    private func contactClient() {
        guard let phoneURL else {
            contactErrorMessage = "当前客户没有可拨打的手机号。"
            return
        }
        UIApplication.shared.open(phoneURL)
    }

    private func openInMaps(_ booking: BookingRecord) {
        let query = booking.navigationQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            navigationErrorMessage = "请先补充拍摄地点。"
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else {
                navigationErrorMessage = "没有找到可导航的位置。"
                return
            }
            item.name = booking.venue.isEmpty ? booking.title : booking.venue
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: selectedTransport.mapKitMode])
        }
    }
}
