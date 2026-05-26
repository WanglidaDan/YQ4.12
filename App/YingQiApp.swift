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
            Group {
                if store.isAuthenticated || hasEnteredGuestMode {
                    RootTabView(store: store)
                } else {
                    AuthGateView(
                        onAuthenticated: { profile in
                            hasEnteredGuestMode = false
                            store.setAuthProfile(profile)
                        },
                        onWeChatSignIn: { completion in
                            weChatAuthService.signIn(completion: completion)
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
            weChatAuthService.registerIfPossible()
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
                        .font(.system(size: min(34, proxy.size.width * 0.088), weight: .semibold, design: .default))
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

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = max(24, min(34, proxy.size.width * 0.075))
            let topPadding = max(30, proxy.safeAreaInsets.top + 24)
            let bottomPadding = max(8, proxy.safeAreaInsets.bottom + 8)
            let maxContentWidth = min(430, proxy.size.width - (horizontalPadding * 2))
            let titleWidth = min(388, proxy.size.width - (horizontalPadding * 2))

            ZStack {
                AuthPremiumBackdrop()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    brandHeader
                        .padding(.top, topPadding)

                    Spacer(minLength: 34)

                    coverHeadline(maxWidth: titleWidth)

                    Spacer(minLength: 42)

                    VStack(spacing: 12) {
                        Text("继续使用影期")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(Color(red: 0.15, green: 0.19, blue: 0.18))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)

                        WeChatAuthButton {
                            AppHaptics.tapLight()
                            onWeChatSignIn { result in
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
                            Text("暂不登录")
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundStyle(Color(red: 0.29, green: 0.34, blue: 0.32))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        }
                        .buttonStyle(.plain)

                        agreementText
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: maxContentWidth)
                    .padding(.bottom, bottomPadding)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var brandHeader: some View {
        HStack(spacing: 12) {
            YingQiBrandMark(size: 52, elevated: false)
            VStack(alignment: .leading, spacing: 3) {
                Text("影期")
                    .font(.system(size: 25, weight: .semibold, design: .default))
                    .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.11))
                Text("YingQi Studio")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.45))
            }
        }
    }

    private func coverHeadline(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("把拍摄工作排得清楚")
                .font(.system(size: min(42, maxWidth * 0.112), weight: .semibold, design: .default))
                .lineSpacing(3)
                .foregroundStyle(Color(red: 0.06, green: 0.08, blue: 0.08))
                .fixedSize(horizontal: false, vertical: true)

            Text("档期、客户、团队和回款，进入后自动同步到你的工作区。")
                .font(.system(size: 16, weight: .regular, design: .default))
                .lineSpacing(5)
                .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.38))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                AuthValueChip(title: "档期")
                AuthValueChip(title: "客户")
                AuthValueChip(title: "团队")
                AuthValueChip(title: "回款")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    private var agreementText: some View {
        HStack(spacing: 0) {
            Text("登录即表示同意 ")
                .foregroundStyle(Color(red: 0.48, green: 0.53, blue: 0.50))
            Button("服务条款") {
                showingLegalDocument = .terms
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.14, green: 0.38, blue: 0.26))
            Text(" 和 ")
                .foregroundStyle(Color(red: 0.48, green: 0.53, blue: 0.50))
            Button("隐私政策") {
                showingLegalDocument = .privacy
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.14, green: 0.38, blue: 0.26))
        }
        .font(.system(size: 13, weight: .medium, design: .default))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
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
        .shadow(color: .black.opacity(elevated ? 0.12 : 0.06), radius: elevated ? 16 : 7, y: elevated ? 9 : 4)
        .accessibilityHidden(true)
    }
}

private struct AuthPremiumBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.96),
                    Color(red: 0.91, green: 0.94, blue: 0.91),
                    Color(red: 0.84, green: 0.89, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.86), location: 0.0),
                    .init(color: .white.opacity(0.38), location: 0.34),
                    .init(color: Color(red: 0.67, green: 0.74, blue: 0.68).opacity(0.18), location: 0.70),
                    .init(color: Color(red: 0.10, green: 0.14, blue: 0.13).opacity(0.08), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Color.white.opacity(0.20)
                    .frame(height: 1)
                Spacer()
                Color(red: 0.08, green: 0.11, blue: 0.10)
                    .opacity(0.05)
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.19))
                    path.addLine(to: CGPoint(x: width, y: height * 0.09))
                    path.addLine(to: CGPoint(x: width, y: height * 0.36))
                    path.addLine(to: CGPoint(x: 0, y: height * 0.50))
                    path.closeSubpath()
                }
                .fill(.white.opacity(0.18))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.70))
                    path.addLine(to: CGPoint(x: width, y: height * 0.58))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.12, green: 0.20, blue: 0.17).opacity(0.06))
            }
        }
    }
}

private struct AuthValueChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(Color(red: 0.18, green: 0.27, blue: 0.22))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.white.opacity(0.54), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
    }
}

private struct WeChatAuthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                WeChatGlyph()

                Text("微信登录")
                    .font(.system(size: 17, weight: .semibold, design: .default))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.68, blue: 0.27),
                        Color(red: 0.04, green: 0.48, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.03, green: 0.30, blue: 0.16).opacity(0.22), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
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
        .signInWithAppleButtonStyle(.black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.12), radius: 14, y: 8)
    }
}
