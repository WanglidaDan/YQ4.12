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
    @State private var weChatAuthService = WeChatAuthService()
    @State private var showingLaunchIntro = false

    init() {
        let initialStore = StudioStore()
        AppTheme.apply(initialStore.settings.themeStyle)
        _store = State(initialValue: initialStore)
    }

    var body: some View {
        ZStack {
            if store.isAuthenticated || hasEnteredGuestMode {
                RootTabView(store: store)
            } else {
                AuthGateView(
                    onAuthenticated: { profile in
                        hasEnteredGuestMode = false
                        store.authenticateForAppEntry(profile)
                    },
                    onWeChatSignIn: { completion in
                        weChatAuthService.signIn(completion: completion)
                    },
                    onContinueWithoutLogin: {
                        enterLocalWorkspace()
                    }
                )
                .environment(store)
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
            ensureLocalWorkspaceOwnerIfNeeded()
            store.normalizeAndPersistIfNeeded()
            BookingReminderActivityManager.shared.sync(
                bookings: store.activeBookings,
                clients: store.activeClients,
                themeStyle: store.settings.themeStyle
            )
        }
        .onAppear {
            weChatAuthService.registerIfPossible()
            ensureLocalWorkspaceOwnerIfNeeded()
            showingLaunchIntro = !hasShownLaunchIntro
        }
        .onOpenURL { url in
            _ = weChatAuthService.handleOpenURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            _ = weChatAuthService.handleUniversalLink(userActivity)
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

    private func enterLocalWorkspace() {
        store.enterLocalWorkspaceAsOwner()
        hasEnteredGuestMode = true
    }

    private func ensureLocalWorkspaceOwnerIfNeeded(force: Bool = false) {
        guard hasEnteredGuestMode || force else { return }
        guard store.isAuthenticated == false else { return }
        store.enterLocalWorkspaceAsOwner()
    }
}

private struct LaunchIntroView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StudioBackdrop(mode: .launch)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    YingQiBrandMark(size: 88, elevated: true)
                    Text("影期")
                        .font(AppTypography.pageTitle)
                        .foregroundStyle(.white.opacity(0.98))
                }
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                .offset(y: -18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AuthGateView: View {
    let onAuthenticated: (AuthProfile) -> Void
    let onWeChatSignIn: (@escaping (Result<AuthProfile, Error>) -> Void) -> Void
    let onContinueWithoutLogin: () -> Void

    @State private var authErrorMessage: String?
    @State private var wechatNoticeMessage: String?
    @State private var showingLegalDocument: AuthLegalDocument?
    @State private var isSigningInWithWeChat = false

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = max(20, min(30, proxy.size.width * 0.065))
            let bottomPadding = max(22, proxy.safeAreaInsets.bottom + 18)
            let topPadding = max(28, proxy.safeAreaInsets.top + 18)
            let maxContentWidth = min(414, proxy.size.width - (horizontalPadding * 2))

            ZStack {
                AuthLuxuryBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 48)

                        VStack(spacing: 14) {
                            YingQiBrandMark(size: 82, elevated: true)

                            Text("影期")
                                .font(AppTypography.pageTitle)
                                .foregroundStyle(AppTheme.ink)

                            Text("摄影档期与客户管理")
                                .font(AppTypography.body)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.top, topPadding)

                        Spacer(minLength: 56)

                        VStack(spacing: 13) {
                            WeChatAuthButton(isLoading: isSigningInWithWeChat) {
                                guard isSigningInWithWeChat == false else { return }
                                AppHaptics.tapLight()
                                isSigningInWithWeChat = true
                                onWeChatSignIn { result in
                                    isSigningInWithWeChat = false
                                    switch result {
                                    case let .success(profile):
                                        AppHaptics.success()
                                        onAuthenticated(profile)
                                    case let .failure(error):
                                        AppHaptics.error()
                                        wechatNoticeMessage = error.localizedDescription
                                    }
                                }
                            }

                            AppleIDAuthButton(
                                onSuccess: onAuthenticated,
                                onFailure: { message in
                                    authErrorMessage = message
                                }
                            )

                            Button {
                                AppHaptics.tapLight()
                                onContinueWithoutLogin()
                            } label: {
                                Text("本机使用")
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                        .stroke(AppTheme.line.opacity(0.65), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)

                            agreementText
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: maxContentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, bottomPadding)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
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
        .alert("微信登录", isPresented: Binding(
            get: { wechatNoticeMessage != nil },
            set: { if $0 == false { wechatNoticeMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(wechatNoticeMessage ?? "")
        }
        .sheet(item: $showingLegalDocument) { document in
            NavigationStack {
                LegalSheetView(title: document.title, bodyText: document.bodyText)
            }
        }
    }

    private var agreementText: some View {
        ViewThatFits {
            HStack(spacing: 0) {
                legalText
            }

            VStack(spacing: 3) {
                legalText
            }
        }
        .font(AppTypography.small)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var legalText: some View {
        Group {
            Text("继续即同意 ")
                .foregroundStyle(AppTheme.secondaryInk)
            Button("服务条款") {
                showingLegalDocument = .terms
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
            Text(" 和 ")
                .foregroundStyle(AppTheme.secondaryInk)
            Button("隐私政策") {
                showingLegalDocument = .privacy
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
        }
    }
}

private struct YingQiBrandMark: View {
    let size: CGFloat
    var elevated: Bool

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(elevated ? 0.24 : 0.08), radius: elevated ? 22 : 7, y: elevated ? 14 : 4)
            .accessibilityHidden(true)
    }
}

private struct AuthLuxuryBackdrop: View {
    var body: some View {
        AppTheme.backgroundGradient
    }
}

private struct WeChatAuthButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                        .frame(width: 30, height: 30)
                } else {
                    WeChatGlyph()
                }

                Text(isLoading ? "正在拉起微信" : "微信登录")
                    .font(AppTypography.rowTitle)

                if isLoading == false {
                    Image(systemName: "arrow.right")
                        .font(AppTypography.icon)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("微信登录")
    }
}

private struct WeChatGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 28, height: 28)

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .offset(x: -4, y: -2)

                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 13, height: 13)
                    .offset(x: 5, y: 4)

                Circle()
                    .fill(Color(red: 0.08, green: 0.72, blue: 0.24))
                    .frame(width: 2.3, height: 2.3)
                    .offset(x: -7.5, y: -3.5)

                Circle()
                    .fill(Color(red: 0.08, green: 0.72, blue: 0.24))
                    .frame(width: 2.3, height: 2.3)
                    .offset(x: -1.5, y: -3.5)

                Circle()
                    .fill(Color(red: 0.08, green: 0.72, blue: 0.24))
                    .frame(width: 1.9, height: 1.9)
                    .offset(x: 3.3, y: 3.2)

                Circle()
                    .fill(Color(red: 0.08, green: 0.72, blue: 0.24))
                    .frame(width: 1.9, height: 1.9)
                    .offset(x: 8, y: 3.2)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
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
                .font(AppTypography.body)
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
                onFailure("Apple 登录失败：\(error.localizedDescription)")
                AppHaptics.error()
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.14), radius: 16, y: 9)
    }
}
