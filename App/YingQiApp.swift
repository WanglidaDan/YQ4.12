import AuthenticationServices
import SwiftUI

@main
struct YingQiApp: App {
    private let appLocale = Locale(identifier: "zh_CN")

    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .environment(\.locale, appLocale)
        }
    }
}

private struct AppRootContainer: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasShownLaunchIntro") private var hasShownLaunchIntro = false
    @AppStorage("hasEnteredGuestMode") private var hasEnteredGuestMode = false
    @State private var store: StudioStore
    @State private var showingLaunchIntro = false

    init() {
        let initialStore = StudioStore()
        AppTheme.apply(initialStore.settings.themeStyle)
        _store = State(initialValue: initialStore)
    }

    var body: some View {
        ZStack {
            Group {
                if store.isAuthenticated || hasEnteredGuestMode {
                    RootTabView(store: store)
                } else {
                    AuthGateView(
                        onAppleSignIn: { profile in
                            hasEnteredGuestMode = false
                            store.setAuthProfile(profile)
                        },
                        onContinueWithoutLogin: {
                            hasEnteredGuestMode = true
                        }
                    )
                    .environment(store)
                }
            }

            if showingLaunchIntro {
                LaunchIntroView()
                    .transition(.opacity)
            }
        }
        .onChange(of: store.settings.themeStyle) { _, newValue in
            AppTheme.apply(newValue)
            BookingReminderActivityManager.shared.sync(
                bookings: store.activeBookings,
                clients: store.activeClients,
                themeStyle: newValue
            )
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            store.normalizeAndPersistIfNeeded()
            BookingReminderActivityManager.shared.sync(
                bookings: store.activeBookings,
                clients: store.activeClients,
                themeStyle: store.settings.themeStyle
            )
        }
        .onAppear {
            showingLaunchIntro = !hasShownLaunchIntro
        }
        .task {
            guard showingLaunchIntro else { return }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.38)) {
                showingLaunchIntro = false
            }
            hasShownLaunchIntro = true
        }
    }
}

private struct LaunchIntroView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StudioBackdrop(mode: .launch)
                    .ignoresSafeArea()

                Text("欢迎来到影期")
                    .font(.system(size: min(36, proxy.size.width * 0.09), weight: .bold, design: .default))
                    .tracking(-0.9)
                    .foregroundStyle(.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                    .offset(y: -18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AuthGateView: View {
    let onAppleSignIn: (AuthProfile) -> Void
    let onContinueWithoutLogin: () -> Void

    @State private var authErrorMessage: String?
    @State private var showingLegalDocument: AuthLegalDocument?

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = max(24, min(34, proxy.size.width * 0.075))
            let topPadding = max(32, proxy.safeAreaInsets.top + 28)
            let bottomPadding = max(8, proxy.safeAreaInsets.bottom + 8)
            let maxContentWidth = min(430, proxy.size.width - (horizontalPadding * 2))
            let titleWidth = min(388, proxy.size.width - (horizontalPadding * 2))

            ZStack {
                StudioBackdrop(mode: .auth)
                    .ignoresSafeArea()

                coverHeadline(maxWidth: titleWidth)
                    .padding(.top, topPadding)
                    .padding(.leading, horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    AppleIDAuthButton(
                        onSuccess: onAppleSignIn,
                        onFailure: { message in
                            authErrorMessage = message
                        }
                    )

                    Button {
                        AppHaptics.tapLight()
                        onContinueWithoutLogin()
                    } label: {
                        Text("暂不登录")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .tracking(0.1)
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    agreementText
                        .padding(.top, 8)
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, bottomPadding)
            }
        }
        .alert("登录失败", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { if $0 == false { authErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(authErrorMessage ?? "")
        }
        .sheet(item: $showingLegalDocument) { document in
            NavigationStack {
                LegalSheetView(title: document.title, bodyText: document.bodyText)
            }
        }
    }

    private func coverHeadline(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("把时间留给创作")
                .font(.system(size: min(38, maxWidth * 0.104), weight: .semibold, design: .default))
                .tracking(-1.2)
                .lineSpacing(0)
                .foregroundStyle(.white.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true)

            Text("管理档期、客户与跟进")
                .font(.system(size: 15, weight: .regular, design: .default))
                .tracking(0.08)
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private var agreementText: some View {
        HStack(spacing: 0) {
            Text("登录即表示同意 ")
                .foregroundStyle(.white.opacity(0.68))
            Button("服务条款") {
                showingLegalDocument = .terms
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.82))
            Text(" 和 ")
                .foregroundStyle(.white.opacity(0.68))
            Button("隐私政策") {
                showingLegalDocument = .privacy
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.82))
        }
        .font(.system(size: 13, weight: .medium, design: .default))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private enum AuthLegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:
            "服务条款"
        case .privacy:
            "隐私政策"
        }
    }

    var bodyText: String {
        switch self {
        case .terms:
            """
            欢迎使用影期。影期是一款面向摄影师与自由创作者的档期、客户、跟进与收款管理工具。

            1. 你可在本地工作区中记录客户资料、订单信息、跟进事项与付款记录，并对你录入的数据准确性负责。
            2. 影期提供归档、删除、导出、备份与恢复功能；删除属于不可恢复操作，请在执行前确认。
            3. 若你选择使用 Apple 登录或 iCloud 同步，相关数据将通过 Apple 提供的能力在你的设备与账户环境内同步。
            4. 影期不会替你向客户自动作出业务承诺，订单确认、价格、交付与收款规则仍由你自行决定并承担责任。
            5. 如遇到异常，请先备份当前工作区，再通过 support@yingqi.app 联系我们。
            """
        case .privacy:
            """
            影期默认优先在本地保存你的档期、客户、跟进、付款、模板和设置数据。

            1. 不登录也可以使用，数据默认保存在本机。
            2. 当你主动使用 Apple 登录时，我们仅保存必要的 Apple 标识信息，用于识别你的工作区身份。
            3. 只有当你在设置页明确开启 iCloud 同步，且设备 iCloud 可用时，数据才会通过你的 Apple 账户在 iCloud 内同步；我们不会将业务数据上传到自有服务器。
            4. 当前版本不提供正式上线的位置或天气能力，也不会在启动时自动请求定位权限。
            5. 你可以在设置页导出、备份、恢复或清空当前工作区；如需隐私支持，请联系 support@yingqi.app。
            """
        }
    }
}

private struct LegalSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}

private struct AppleIDAuthButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let onSuccess: (AuthProfile) -> Void
    let onFailure: (String) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case let .success(authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    onFailure("没有获取到可用的 Apple 登录凭证。")
                    AppHaptics.error()
                    return
                }

                let fullName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
                let normalizedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                let profile = AuthProfile(
                    appleUserID: credential.user,
                    email: credential.email,
                    fullName: normalizedName.isEmpty ? nil : normalizedName
                )
                AppHaptics.success()
                onSuccess(profile)
            case let .failure(error):
                onFailure(error.localizedDescription)
                AppHaptics.error()
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .black : .white)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
    }
}
