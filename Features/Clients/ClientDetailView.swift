import SwiftUI

private struct ClientBookingRoute: Hashable {
    let bookingID: UUID
}

struct ClientDetailView: View {
    @Environment(StudioStore.self) private var store

    let clientID: UUID

    @State private var editingClient: ClientRecord?
    @State private var businessCenterRoute: BusinessCenterRoute?

    private let calendar = Calendar.current

    private var client: ClientRecord? {
        store.client(id: clientID)
    }

    private var relatedBookings: [BookingRecord] {
        store.bookings(for: clientID)
    }

    private var relatedTouchpoints: [TouchpointRecord] {
        store.touchpoints(for: clientID)
    }

    private var phoneURL: URL? {
        guard let phone = client?.phoneNumber else { return nil }
        let digits = AppFormatters.sanitizedPhoneNumber(phone)
        guard digits.isEmpty == false else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var body: some View {
        Group {
            if let client {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        heroCard(client)
                        actionBar(client)
                        statsGrid(client)
                        notesSection(client)
                        businessCenterSection(client)
                        bookingsSection
                        touchpointsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
                .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("编辑", systemImage: "square.and.pencil") {
                            editingClient = client
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "客户不存在",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("当前客户可能已被删除。")
                )
            }
        }
        .navigationTitle("客户详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editingClient) { client in
            ClientEditorView(client: client)
        }
        .sheet(item: $businessCenterRoute) { route in
            BusinessCenterView(
                initialMode: route.mode,
                bookingID: route.bookingID,
                clientID: route.clientID
            )
            .environment(store)
        }
        .navigationDestination(for: ClientBookingRoute.self) { route in
            BookingDetailView(bookingID: route.bookingID)
        }
    }

    private func heroCard(_ client: ClientRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.accentSurface)
                        .frame(width: 70, height: 70)
                    Text(client.initials)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppTheme.accentDeep)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(client.name)
                            .font(AppTypography.heroTitle)
                            .foregroundStyle(AppTheme.ink)
                        TierBadge(tier: client.tier)
                    }

                    Text("\(client.city) · \(client.sourceChannel)")
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryInk)

                    HStack(spacing: 8) {
                        LeadStageBadge(stage: client.stage)
                        if let nextDue = store.nextPendingTouchpoint(for: client.id)?.dueAt ?? client.nextContactAt {
                            statusPill(title: AppFormatters.relativeDueText(nextDue, calendar: calendar), icon: "calendar.badge.clock")
                        }
                    }
                }

                Spacer()
            }

            Text(client.notesText)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                .stroke(AppTheme.line.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }

    @ViewBuilder
    private func actionBar(_: ClientRecord) -> some View {
        if let phoneURL {
            Link(destination: phoneURL) {
                Label("联系客户", systemImage: "phone.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
    }

    private func statsGrid(_ client: ClientRecord) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            detailMetric(title: "累计合作", value: AppFormatters.currency(store.lifetimeValue(for: client.id)))
            detailMetric(title: "待回款", value: AppFormatters.currency(store.outstandingValue(for: client.id)))
            detailMetric(title: "关联档期", value: "\(relatedBookings.count)")
            detailMetric(title: "跟进任务", value: "\(store.pendingTouchpoints(for: client.id).count)")
        }
    }

    private func notesSection(_ client: ClientRecord) -> some View {
        GlassCard(title: "经营信息", subtitle: "记录客户画像、合作偏好与下次动作") {
            VStack(spacing: 12) {
                detailRow("电话", client.phoneNumber)
                detailRow("阶段", client.stage.title)
                detailRow("层级", client.tier.title)
                if let lastContactAt = client.lastContactAt {
                    detailRow("上次联系", AppFormatters.shortDate(lastContactAt))
                }
                if let nextContactAt = store.nextPendingTouchpoint(for: client.id)?.dueAt ?? client.nextContactAt {
                    detailRow("下次跟进", AppFormatters.shortDate(nextContactAt))
                }
            }
        }
    }

    private func businessCenterSection(_ client: ClientRecord) -> some View {
        let summary = store.businessSummary(for: nil, clientID: client.id)
        let clientBookings = store.bookings(for: client.id)
        let outstanding = store.outstandingValue(for: client.id)

        return GlassCard(title: "业务闭环与资料中心", subtitle: "围绕这个客户补齐报价、合同、资料、报表。") {
            HStack(spacing: 12) {
                AppMetricTile(title: "业务文档", value: "\(summary.documents)", subtitle: "报价 / 合同 / 收据 / 发票", fillColor: AppTheme.panelStrong)
                AppMetricTile(title: "资料", value: "\(summary.attachments)", subtitle: clientBookings.isEmpty ? "尚未关联订单" : "\(clientBookings.count) 条订单上下文", fillColor: AppTheme.panelStrong)
            }

            AppKeyValueRow(title: "累计合作", value: AppFormatters.currency(store.lifetimeValue(for: client.id)))
            AppKeyValueRow(title: "待回款", value: AppFormatters.currency(outstanding))

            VStack(spacing: 10) {
                clientBusinessButton(mode: .workflow, subtitle: "报价、合同、收据、发票", clientID: client.id)
                clientBusinessButton(mode: .assets, subtitle: "参考资料、合同附件、交付链接", clientID: client.id)
                clientBusinessButton(mode: .analytics, subtitle: "复购、客单价、渠道贡献", clientID: client.id)
            }
        }
    }

    private func clientBusinessButton(mode: BusinessCenterMode, subtitle: String, clientID: UUID) -> some View {
        Button {
            businessCenterRoute = BusinessCenterRoute(mode: mode, bookingID: nil, clientID: clientID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(14)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bookingsSection: some View {
        GlassCard(title: "关联档期", subtitle: relatedBookings.isEmpty ? "还没有与该客户绑定的拍摄" : "共 \(relatedBookings.count) 场") {
            LazyVStack(spacing: 12) {
                if relatedBookings.isEmpty {
                    placeholderCard(
                        title: "暂未绑定项目",
                        subtitle: "当你在档期里关联这个客户后，会自动形成完整的合作轨迹。"
                    )
                } else {
                    ForEach(relatedBookings) { booking in
                        NavigationLink(value: ClientBookingRoute(bookingID: booking.id)) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(booking.title)
                                                .font(.headline)
                                                .foregroundStyle(AppTheme.ink)
                                            ServiceCategoryBadge(category: booking.category)
                                        }
                                        Text("\(AppFormatters.shortDate(booking.startAt)) · \(booking.venue)")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.secondaryInk)
                                    }
                                    Spacer()
                                    BookingStatusBadge(status: booking.status)
                                }

                                HStack {
                                    detailMeta(title: "总价", value: AppFormatters.currency(booking.fee))
                                    Spacer()
                                    detailMeta(title: "待回款", value: AppFormatters.currency(store.outstandingAmount(for: booking)))
                                }
                            }
                            .padding(16)
                            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .stroke(AppTheme.line.opacity(0.78), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var touchpointsSection: some View {
        GlassCard(title: "跟进轨迹", subtitle: relatedTouchpoints.isEmpty ? "还没有跟进动作" : "按时间顺序查看与客户的每次触达") {
            LazyVStack(spacing: 12) {
                if relatedTouchpoints.isEmpty {
                    placeholderCard(
                        title: "暂无跟进记录",
                        subtitle: "建议记录报价推进、拍前确认或交付回访，让合作上下文更完整。"
                    )
                } else {
                    ForEach(relatedTouchpoints) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(item.detailsText)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                        .lineLimit(3)
                                }
                                Spacer()
                                PriorityBadge(priority: item.priority)
                            }

                            HStack {
                                Label(item.channel.title, systemImage: item.channel.symbolName)
                                    .font(AppTypography.meta)
                                    .foregroundStyle(AppTheme.mutedInk)
                                Spacer()
                                Text(item.isComplete ? "已完成" : AppFormatters.relativeDueText(item.dueAt, calendar: calendar))
                                    .font(AppTypography.meta)
                                    .foregroundStyle(item.isComplete ? AppTheme.success : AppTheme.warning)
                            }

                            if item.isComplete == false {
                                Button("标记完成", systemImage: "checkmark.circle.fill") {
                                    store.markTouchpointComplete(item.id)
                                }
                                .buttonStyle(AppSecondaryButtonStyle())
                            }
                        }
                        .padding(16)
                        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .stroke(AppTheme.line.opacity(0.78), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.line.opacity(0.78), lineWidth: 1)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func detailMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private func statusPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.meta)
            .foregroundStyle(AppTheme.accentDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accentSurface, in: RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous))
    }

    private func placeholderCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.line.opacity(0.78), lineWidth: 1)
        }
    }
}
