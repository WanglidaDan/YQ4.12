import AuthenticationServices
import SwiftUI
import UIKit

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
            let horizontalPadding = max(20, min(30, proxy.size.width * 0.065))
            let bottomPadding = max(18, proxy.safeAreaInsets.bottom + 14)
            let maxContentWidth = min(414, proxy.size.width - (horizontalPadding * 2))

            ZStack {
                AuthLuxuryBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 84)

                    VStack(spacing: 20) {
                        YingQiBrandMark(size: 96, elevated: true)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            }

                        VStack(spacing: 7) {
                            Text("影期")
                                .font(.system(size: 38, weight: .semibold, design: .default))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.96))

                            Text("YingQi Studio")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.48))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 78)

                    VStack(spacing: 14) {
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
                            Text("稍后再说")
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.50))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .frame(maxWidth: maxContentWidth)
                    .background {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.62))
                            .overlay {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.white.opacity(0.055))
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.11), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.26), radius: 28, y: 18)

                    Spacer(minLength: 22)

                    agreementText
                        .frame(maxWidth: maxContentWidth)
                        .padding(.bottom, bottomPadding)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
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
        HStack(spacing: 0) {
            Text("继续即同意 ")
                .foregroundStyle(.white.opacity(0.34))
            Button("服务条款") {
                showingLegalDocument = .terms
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.62))
            Text(" 和 ")
                .foregroundStyle(.white.opacity(0.34))
            Button("隐私政策") {
                showingLegalDocument = .privacy
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.62))
        }
        .font(.system(size: 12, weight: .medium, design: .default))
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
            .shadow(color: .black.opacity(elevated ? 0.24 : 0.08), radius: elevated ? 22 : 7, y: elevated ? 14 : 4)
            .accessibilityHidden(true)
    }
}

private struct AuthLuxuryBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.055, blue: 0.045),
                    Color(red: 0.035, green: 0.120, blue: 0.095),
                    Color(red: 0.008, green: 0.020, blue: 0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.43, green: 0.57, blue: 0.42).opacity(0.34),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
            .offset(x: 80, y: -120)

            RadialGradient(
                colors: [
                    Color(red: 0.68, green: 0.54, blue: 0.36).opacity(0.18),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 360
            )
            .offset(x: -80, y: 160)

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.08), location: 0.0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.22), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
                        Color(red: 0.08, green: 0.70, blue: 0.28),
                        Color(red: 0.03, green: 0.45, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.00, green: 0.24, blue: 0.12).opacity(0.34), radius: 18, y: 10)
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
    @StateObject private var coordinator = AppleSignInCoordinator()

    let onSuccess: (AuthProfile) -> Void
    let onFailure: (String) -> Void

    var body: some View {
        Button {
            AppHaptics.tapLight()
            coordinator.signIn(onSuccess: onSuccess, onFailure: onFailure)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 21, weight: .semibold))
                Text("Apple 登录")
                    .font(.system(size: 17, weight: .semibold, design: .default))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.26), radius: 16, y: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple 登录")
    }
}

private final class AppleSignInCoordinator: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var onSuccess: ((AuthProfile) -> Void)?
    private var onFailure: ((String) -> Void)?

    func signIn(
        onSuccess: @escaping (AuthProfile) -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onFailure?("没有获取到可用的 Apple 登录凭证。")
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
        onSuccess?(profile)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailure?(error.localizedDescription)
        AppHaptics.error()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
