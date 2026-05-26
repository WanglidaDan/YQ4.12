# 微信真实登录配置

当前 iOS 端已经接入 WechatOpenSDK，并会在微信授权返回 `code` 后调用服务端换码接口。真实可用还需要完成下面配置。

## 1. 微信开放平台

在微信开放平台创建或打开移动应用，配置：

- iOS Bundle ID：`com.wanglida.YingQi`
- iOS Universal Link：`https://你的域名/wechat/`

审核通过后拿到：

- `WECHAT_APP_ID`
- `WECHAT_APP_SECRET`

`AppSecret` 只能放服务端，不能写进 iOS App。

## 2. 服务端换码接口

已提供 Cloudflare Worker 模板：

- [worker.js](../Server/wechat-auth-worker/worker.js)
- [wrangler.toml.example](../Server/wechat-auth-worker/wrangler.toml.example)

Worker 提供两个能力：

- `GET /.well-known/apple-app-site-association`：给 iOS Universal Link 校验使用。
- `POST /wechat/exchange`：iOS 端拿 `code` 后调用，服务端用 `AppSecret` 换取 `openid/unionid`。

需要配置环境变量：

```text
APPLE_TEAM_ID=9ZV32GL37D
IOS_BUNDLE_ID=com.wanglida.YingQi
WECHAT_APP_ID=wx...
WECHAT_APP_SECRET=...
```

`WECHAT_APP_SECRET` 必须用 Secret 管理。

## 3. iOS 配置

部署 Worker 后，把下面三项写入 `Config/AppDebug.xcconfig` 和 `Config/AppRelease.xcconfig`：

```xcconfig
WECHAT_APP_ID = wx...
WECHAT_UNIVERSAL_LINK = https://你的域名/wechat/
WECHAT_AUTH_EXCHANGE_ENDPOINT = https://你的域名/wechat/exchange
WECHAT_ASSOCIATED_DOMAIN = 你的域名
```

然后重新执行：

```bash
xcodegen generate
xcodebuild -project YingQi.xcodeproj -scheme YingQi -destination 'generic/platform=iOS Simulator' build
```

## 4. 返回数据格式

iOS 端期望 `/wechat/exchange` 返回：

```json
{
  "openid": "微信 openid",
  "unionid": "微信 unionid，可选但优先使用",
  "nickname": "微信昵称，可选",
  "avatar_url": "头像 URL，可选"
}
```

登录身份会按 `unionid` 优先、`openid` 兜底写入本地工作区。
