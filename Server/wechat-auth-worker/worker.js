const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (request.method === "GET" && isAASAPath(url.pathname)) {
      return jsonResponse(makeAASA(env), 200, {
        "content-type": "application/json",
        "cache-control": "public, max-age=300",
      });
    }

    if (request.method === "POST" && url.pathname === "/wechat/exchange") {
      return handleWeChatExchange(request, env);
    }

    return jsonResponse({ error: "not_found" }, 404);
  },
};

async function handleWeChatExchange(request, env) {
  const appID = requiredEnv(env, "WECHAT_APP_ID");
  const appSecret = requiredEnv(env, "WECHAT_APP_SECRET");
  if (!appID || !appSecret) {
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const code = normalize(body.code);
  const clientAppID = normalize(body.app_id);
  if (!code) {
    return jsonResponse({ error: "missing_code" }, 400);
  }
  if (clientAppID && clientAppID !== appID) {
    return jsonResponse({ error: "appid_mismatch" }, 403);
  }

  const tokenURL = new URL("https://api.weixin.qq.com/sns/oauth2/access_token");
  tokenURL.searchParams.set("appid", appID);
  tokenURL.searchParams.set("secret", appSecret);
  tokenURL.searchParams.set("code", code);
  tokenURL.searchParams.set("grant_type", "authorization_code");

  const tokenPayload = await fetchWeChatJSON(tokenURL);
  if (tokenPayload.errcode) {
    return jsonResponse(
      {
        error: "wechat_token_failed",
        errcode: tokenPayload.errcode,
        errmsg: tokenPayload.errmsg,
      },
      502
    );
  }

  const openid = normalize(tokenPayload.openid);
  const unionid = normalize(tokenPayload.unionid);
  if (!openid && !unionid) {
    return jsonResponse({ error: "missing_openid" }, 502);
  }

  const userInfo = await fetchUserInfoIfPossible(tokenPayload, openid);
  return jsonResponse({
    openid,
    unionid: unionid || normalize(userInfo.unionid),
    nickname: normalize(userInfo.nickname),
    avatar_url: normalize(userInfo.headimgurl),
    scope: normalize(tokenPayload.scope),
  });
}

async function fetchUserInfoIfPossible(tokenPayload, openid) {
  const accessToken = normalize(tokenPayload.access_token);
  const scope = normalize(tokenPayload.scope);
  if (!accessToken || !openid || !scope.includes("snsapi_userinfo")) {
    return {};
  }

  const userInfoURL = new URL("https://api.weixin.qq.com/sns/userinfo");
  userInfoURL.searchParams.set("access_token", accessToken);
  userInfoURL.searchParams.set("openid", openid);
  userInfoURL.searchParams.set("lang", "zh_CN");

  const payload = await fetchWeChatJSON(userInfoURL);
  return payload.errcode ? {} : payload;
}

async function fetchWeChatJSON(url) {
  const response = await fetch(url.toString(), {
    method: "GET",
    headers: { accept: "application/json" },
  });
  return response.json();
}

function makeAASA(env) {
  const teamID = requiredEnv(env, "APPLE_TEAM_ID");
  const bundleID = requiredEnv(env, "IOS_BUNDLE_ID") || "com.wanglida.YingQi";
  const appID = teamID ? `${teamID}.${bundleID}` : bundleID;

  return {
    applinks: {
      details: [
        {
          appIDs: [appID],
          components: [
            {
              "/": "/wechat/*",
              comment: "WeChat login Universal Link callback",
            },
          ],
        },
      ],
    },
  };
}

function isAASAPath(pathname) {
  return pathname === "/apple-app-site-association" ||
    pathname === "/.well-known/apple-app-site-association";
}

function requiredEnv(env, key) {
  return normalize(env[key]);
}

function normalize(value) {
  return typeof value === "string" ? value.trim() : "";
}

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...jsonHeaders,
      ...extraHeaders,
    },
  });
}

function corsHeaders(request) {
  const origin = request.headers.get("origin") || "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type",
    "access-control-max-age": "86400",
  };
}
