import SwiftUI

struct StandardProfileView: View {
    @Environment(StudioStore.self) private var store
    @AppStorage("hasEnteredGuestMode") private var hasEnteredGuestMode = false

    @State private var confirmingSignOut = false
    @State private var confirmingClearData = false

    private var profile: StudioProfile {
        store.resolvedStudioProfile
    }

    private var workspaceName: String {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "影期工作区" : name
    }

    private var accountStatus: String {
        store.isAuthenticated ? "已登录" : "本机模式"
    }

    private var syncStatus: String {
        store.settings.iCloudSyncEnabled ? "iCloud 同步" : "本机保存"
    }

    private var studioModeStatus: String {
        store.settings.studioModeEnabled ? "成员协作" : "个人工作区"
    }

    private var outstandingTotal: Double {
        store.activeBookings.reduce(0) { partialResult, booking in
            partialResult + store.outstandingAmount(for: booking)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerTitle
                        identityHero
                        workspaceLedger
                        accountActions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("确认退出登录？", isPresented: $confirmingSignOut) {
                Button("退出登录", role: .destructive) {
                    store.clearAuthProfile()
                    hasEnteredGuestMode = false
                    AppHaptics.success()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后会回到登录页，当前设备上的本地工作区会保留。")
            }
            .confirmationDialog("确认清空当前工作区？", isPresented: $confirmingClearData) {
                Button("清空工作区", role: .destructive) {
                    store.clearAllData()
                    AppHaptics.success()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这会清空当前设备上的客户、档期、跟进和经营数据。")
            }
        }
    }

    private var headerTitle: some View {
        AppPageHeader(title: "我的", subtitle: "账户、工作区和数据管理")
    }

    private var identityHero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 15) {
                Image("BrandLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 7) {
                    Text(workspaceName)
                        .font(AppTypography.heroTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(accountStatus) · \(syncStatus) · \(studioModeStatus)")
                        .font(AppTypography.badge)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(.white.opacity(0.18))

            HStack(spacing: 0) {
                heroMetric(title: "档期", value: "\(store.activeBookings.count)", subtitle: "进行中")
                heroDivider
                heroMetric(title: "客户", value: "\(store.activeClients.count)", subtitle: "活跃关系")
                heroDivider
                heroMetric(title: "待收", value: AppFormatters.currency(outstandingTotal), subtitle: "未结清")
            }
        }
        .padding(22)
        .background(identityHeroBackground)
        .shadow(color: AppTheme.deepShadow.opacity(0.16), radius: 22, y: 12)
    }

    private var identityHeroBackground: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)

            LinearGradient(
                colors: [.white.opacity(0.12), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private func heroMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(title)
                .font(AppTypography.badge)
                .foregroundStyle(.white.opacity(0.72))
            Text(subtitle)
                .font(AppTypography.micro)
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 52)
            .padding(.horizontal, 14)
    }

    private var workspaceLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "工作区", subtitle: "当前使用状态")
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                infoRow(symbol: "person.crop.circle", title: "账户状态", value: accountStatus)
                rowDivider
                infoRow(symbol: store.settings.iCloudSyncEnabled ? "icloud" : "iphone", title: "数据保存", value: syncStatus)
                rowDivider
                infoRow(symbol: "camera.aperture", title: "工作模式", value: studioModeStatus)
                rowDivider
                infoRow(symbol: "creditcard", title: "待收金额", value: AppFormatters.currency(outstandingTotal))
            }
            .padding(.vertical, 4)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
            }
        }
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "管理", subtitle: "设置、数据和登录")
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                NavigationLink {
                    SettingsView(store: store, showsCloseButton: false)
                        .environment(store)
                } label: {
                    actionRow(
                        symbol: "gearshape",
                        title: "设置",
                        subtitle: "主题、同步、团队、导出和备份",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                Button {
                    confirmingClearData = true
                } label: {
                    actionRow(
                        symbol: "trash",
                        title: "清空当前工作区",
                        subtitle: "保留登录状态和基础设置",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                Button {
                    confirmingSignOut = true
                } label: {
                    actionRow(
                        symbol: "rectangle.portrait.and.arrow.right",
                        title: "退出登录",
                        subtitle: "返回登录页，本地工作区保留",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppTheme.line.opacity(0.72))
            .padding(.leading, 64)
    }

    private func infoRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 34, height: 34)

            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.ink)

            Spacer(minLength: 8)

            Text(value)
                .font(AppTypography.rowValue)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func actionRow(symbol: String, title: String, subtitle: String, showsChevron: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTypography.small)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}
