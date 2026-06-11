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
                    VStack(alignment: .leading, spacing: 18) {
                        profileHero
                        workSummary
                        settingsPanel
                        dataPanel
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
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

    private var profileHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image("BrandLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(workspaceName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)

                    Text("\(accountStatus) · \(syncStatus)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                ProfileStatusBadge(symbol: "person.crop.circle", title: accountStatus)
                ProfileStatusBadge(symbol: store.settings.iCloudSyncEnabled ? "icloud" : "iphone", title: syncStatus)
                ProfileStatusBadge(symbol: "camera.aperture", title: studioModeStatus)
            }
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.hero, fillColor: AppTheme.panelSoft, style: .emphasized)
    }

    private var workSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("工作区")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ProfileMetricTile(title: "档期", value: "\(store.activeBookings.count)", subtitle: "进行中")
                ProfileMetricTile(title: "客户", value: "\(store.activeClients.count)", subtitle: "活跃关系")
                ProfileMetricTile(title: "待收", value: AppFormatters.currency(outstandingTotal), subtitle: "未结清")
                ProfileMetricTile(title: "协作", value: store.settings.studioModeEnabled ? "开启" : "个人", subtitle: syncStatus)
            }
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            NavigationLink {
                SettingsView(store: store, showsCloseButton: false)
                    .environment(store)
            } label: {
                ProfileActionRow(
                    symbol: "gearshape",
                    title: "完整设置",
                    subtitle: "主题、同步、团队、导出和备份",
                    tint: AppTheme.accent
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }

    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Button {
                confirmingClearData = true
            } label: {
                ProfileActionRow(
                    symbol: "trash",
                    title: "清空当前工作区",
                    subtitle: "保留登录状态和基础设置",
                    tint: AppTheme.danger
                )
            }
            .buttonStyle(.plain)

            Button {
                confirmingSignOut = true
            } label: {
                ProfileActionRow(
                    symbol: "rectangle.portrait.and.arrow.right",
                    title: "退出登录",
                    subtitle: "返回登录页，本地工作区保留",
                    tint: AppTheme.warning
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .appCardSurface(cornerRadius: AppRadius.card, fillColor: AppTheme.panel)
    }
}

private struct ProfileStatusBadge: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(AppTheme.secondaryInk)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(AppTheme.panelStrong.opacity(0.72), in: Capsule())
    }
}

private struct ProfileMetricTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.panelStrong.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }
}

private struct ProfileActionRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.55))
        }
        .padding(12)
        .background(AppTheme.panelStrong.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }
}
