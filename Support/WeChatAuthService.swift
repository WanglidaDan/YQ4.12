import Foundation
import UIKit

#if canImport(WechatOpenSDK)
import WechatOpenSDK
#endif

@MainActor
final class WeChatAuthService: NSObject {
    private var pendingState: String?
    private var pendingCompletion: ((Result<AuthProfile, Error>) -> Void)?
    private var hasRegistered = false

    private var configuration: WeChatAuthConfiguration {
        WeChatAuthConfiguration.current
    }

    var isAvailable: Bool {
        configuration.isSDKReady && configuration.exchangeEndpoint != nil
    }

    func registerIfPossible() {
        guard configuration.isSDKReady else { return }
        registerIfNeeded()
    }

    func signIn(completion: @escaping (Result<AuthProfile, Error>) -> Void) {
        let config = configuration
        guard config.hasAppID else {
            completion(.failure(WeChatAuthError.missingAppID))
            return
        }
        guard config.hasUniversalLink else {
            completion(.failure(WeChatAuthError.missingUniversalLink))
            return
        }
        guard registerIfNeeded() else {
            completion(.failure(WeChatAuthError.registrationFailed))
            return
        }

        #if canImport(WechatOpenSDK)
        let state = "yingqi-\(UUID().uuidString)"
        let request = SendAuthReq()
        request.scope = "snsapi_userinfo"
        request.state = state
        request.nonautomatic = false

        pendingState = state
        pendingCompletion = completion

        guard let viewController = UIApplication.shared.yingqiTopViewController else {
            clearPending()
            completion(.failure(WeChatAuthError.missingPresenter))
            return
        }

        WXApi.sendAuthReq(request, viewController: viewController, delegate: self) { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                if success == false {
                    self.finish(.failure(WeChatAuthError.sendFailed))
                }
            }
        }
        #else
        completion(.failure(WeChatAuthError.sdkUnavailable))
        #endif
    }

    func handleOpenURL(_ url: URL) -> Bool {
        #if canImport(WechatOpenSDK)
        return WXApi.handleOpen(url, delegate: self)
        #else
        return false
        #endif
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        #if canImport(WechatOpenSDK)
        return WXApi.handleOpenUniversalLink(userActivity, delegate: self)
        #else
        return false
        #endif
    }

    @discardableResult
    private func registerIfNeeded() -> Bool {
        guard hasRegistered == false else { return true }
        let config = configuration
        guard config.isSDKReady else { return false }

        #if canImport(WechatOpenSDK)
        let success = WXApi.registerApp(config.appID, universalLink: config.universalLink)
        hasRegistered = success
        return success
        #else
        return false
        #endif
    }

    private func handleAuthResponse(_ response: SendAuthResp) {
        guard response.state == pendingState else {
            finish(.failure(WeChatAuthError.invalidState))
            return
        }

        switch Int(response.errCode) {
        case 0:
            guard let code = response.code?.trimmingCharacters(in: .whitespacesAndNewlines), code.isEmpty == false else {
                finish(.failure(WeChatAuthError.missingCode))
                return
            }
            Task { [weak self] in
                guard let self else { return }
                let result = await self.exchangeCodeForProfile(code: code, state: response.state)
                await MainActor.run {
                    self.finish(result)
                }
            }
        case -2:
            finish(.failure(WeChatAuthError.cancelled))
        case -4:
            finish(.failure(WeChatAuthError.denied(response.errStr)))
        default:
            finish(.failure(WeChatAuthError.responseFailed(code: Int(response.errCode), message: response.errStr)))
        }
    }

    private func exchangeCodeForProfile(code: String, state: String?) async -> Result<AuthProfile, Error> {
        let config = configuration
        guard let endpoint = config.exchangeEndpoint else {
            return .failure(WeChatAuthError.missingExchangeEndpoint)
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(WeChatAuthExchangeRequest(
                appID: config.appID,
                code: code,
                state: state
            ))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .failure(WeChatAuthError.exchangeFailed)
            }

            let payload = try JSONDecoder().decode(WeChatAuthExchangeResponse.self, from: data)
            guard let subjectID = payload.subjectID else {
                return .failure(WeChatAuthError.missingOpenID)
            }

            let displayName = payload.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profile = AuthProfile(
                appleUserID: "wechat:\(subjectID)",
                email: payload.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                fullName: displayName?.nilIfEmpty
            )
            return .success(profile)
        } catch {
            return .failure(WeChatAuthError.exchangeUnderlying(error))
        }
    }

    private func finish(_ result: Result<AuthProfile, Error>) {
        let completion = pendingCompletion
        clearPending()
        completion?(result)
    }

    private func clearPending() {
        pendingState = nil
        pendingCompletion = nil
    }
}

#if canImport(WechatOpenSDK)
extension WeChatAuthService: WXApiDelegate {
    nonisolated func onResp(_ resp: BaseResp) {
        guard let authResponse = resp as? SendAuthResp else { return }
        Task { @MainActor in
            self.handleAuthResponse(authResponse)
        }
    }

    nonisolated func onReq(_ req: BaseReq) {}

    nonisolated func onNeedGrantReadPasteBoardPermission(with openURL: URL, completion: @escaping WXGrantReadPasteBoardPermissionCompletion) {
        _ = completion()
    }
}
#endif

private struct WeChatAuthConfiguration {
    let appID: String
    let universalLink: String
    let exchangeEndpoint: URL?

    static var current: WeChatAuthConfiguration {
        let bundle = Bundle.main
        return WeChatAuthConfiguration(
            appID: normalizedString(bundle.object(forInfoDictionaryKey: "WECHAT_APP_ID")),
            universalLink: normalizedString(bundle.object(forInfoDictionaryKey: "WECHAT_UNIVERSAL_LINK")),
            exchangeEndpoint: URL(string: normalizedString(bundle.object(forInfoDictionaryKey: "WECHAT_AUTH_EXCHANGE_ENDPOINT")))
        )
    }

    var hasAppID: Bool {
        appID.isEmpty == false
    }

    var hasUniversalLink: Bool {
        universalLink.hasPrefix("https://")
    }

    var isSDKReady: Bool {
        hasAppID && hasUniversalLink
    }

    private static func normalizedString(_ value: Any?) -> String {
        guard let string = value as? String else { return "" }
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.contains("$(") ? "" : normalized
    }
}

private struct WeChatAuthExchangeRequest: Encodable {
    let appID: String
    let code: String
    let state: String?

    enum CodingKeys: String, CodingKey {
        case appID = "app_id"
        case code
        case state
    }
}

private struct WeChatAuthExchangeResponse: Decodable {
    let openID: String?
    let unionID: String?
    let nickname: String?
    let email: String?

    var subjectID: String? {
        unionID?.nilIfEmpty ?? openID?.nilIfEmpty
    }

    enum CodingKeys: String, CodingKey {
        case openID = "openid"
        case unionID = "unionid"
        case nickname
        case email
    }
}

private enum WeChatAuthError: LocalizedError {
    case sdkUnavailable
    case missingAppID
    case missingUniversalLink
    case registrationFailed
    case missingPresenter
    case sendFailed
    case invalidState
    case missingCode
    case cancelled
    case denied(String?)
    case responseFailed(code: Int, message: String?)
    case missingExchangeEndpoint
    case exchangeFailed
    case exchangeUnderlying(Error)
    case missingOpenID

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            "当前构建没有集成 WechatOpenSDK。"
        case .missingAppID:
            "还没有配置微信开放平台 AppID。请在 AppDebug/AppRelease.xcconfig 填入 WECHAT_APP_ID。"
        case .missingUniversalLink:
            "还没有配置微信 Universal Link。请在 AppDebug/AppRelease.xcconfig 填入 WECHAT_UNIVERSAL_LINK，并确保微信开放平台和 Apple Associated Domains 使用同一个链接。"
        case .registrationFailed:
            "微信 SDK 注册失败，请检查 AppID、Universal Link、URL Scheme 和 Associated Domains 配置。"
        case .missingPresenter:
            "当前没有可用于拉起微信授权的界面。"
        case .sendFailed:
            "没有成功拉起微信授权，请确认设备已安装微信，且当前 AppID 与 Bundle ID 已在微信开放平台审核通过。"
        case .invalidState:
            "微信授权返回校验失败，请重新登录。"
        case .missingCode:
            "微信没有返回授权 code，请重新登录。"
        case .cancelled:
            "你取消了微信登录。"
        case let .denied(message):
            message?.nilIfEmpty ?? "微信授权被拒绝。"
        case let .responseFailed(code, message):
            "微信授权失败（\(code)）：\(message?.nilIfEmpty ?? "未知错误")"
        case .missingExchangeEndpoint:
            "已收到微信授权 code，但还没有配置服务端换码接口 WECHAT_AUTH_EXCHANGE_ENDPOINT。iOS 端不能内置 AppSecret，必须由服务端换取 openid/unionid 后完成登录。"
        case .exchangeFailed:
            "服务端微信换码失败，请检查接口返回状态。"
        case let .exchangeUnderlying(error):
            "服务端微信换码失败：\(error.localizedDescription)"
        case .missingOpenID:
            "服务端换码结果缺少 openid 或 unionid。"
        }
    }
}

private extension UIApplication {
    var yingqiTopViewController: UIViewController? {
        let activeScene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var current = activeScene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
