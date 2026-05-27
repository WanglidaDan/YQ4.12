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
        store.settings.iCloudSyncEnabled ? "iCloud 同步已开启" : "本机保存"
    }

    private var studioModeStatus: String {
        store.settings.studioModeEnabled ? "团队模式" : "个人模式"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
                }

                Section("工作概览") {
                    LabeledContent("客户", value: "\(store.activeClients.count) 位")
                    LabeledContent("团队", value: "\(store.activeCrewMembers.count) 位")
                    LabeledContent("档期", value: "\(store.activeBookings.count) 个")
                }

                Section("当前状态") {
                    LabeledContent("账号", value: accountStatus)
                    LabeledContent("同步", value: syncStatus)
                    LabeledContent("模式", value: studioModeStatus)
                }

                Section("设置") {
                    NavigationLink {
                        SettingsView(store: store)
                            .environment(store)
                    } label: {
                        Label("完整设置", systemImage: "gearshape")
                    }
                }

                Section("数据") {
                    Button(role: .destructive) {
                        confirmingClearData = true
                    } label: {
                        Label("清空当前工作区", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        confirmingSignOut = true
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
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

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(workspaceName)
                    .font(.headline)
                    .lineLimit(2)

                Text(accountStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
