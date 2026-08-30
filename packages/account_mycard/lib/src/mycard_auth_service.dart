/// MyCard（萌卡/moecube）认证服务。
///
/// 登录走账号密码直登 API：`POST /accounts/signin`（YGOMobile 同款），
/// **不使用网页 SSO**（neos-ts 的 accounts.moecube.com 重定向流程）。
///
///  - `u16Secret` 是匹配与房间认证的时间轮换密钥，每次使用前重新获取；
///  - 匹配 Basic auth 使用 `username:u16Secret`（无 u16Secret 时退回
///    external_id）。
library;

import 'dart:async';
import 'dart:convert';
import 'package:applog/console.dart' as console;

import 'package:http/http.dart' as http;

import 'mycard_account.dart';

/// MyCard/moecube 公共服务地址。
class MyCardEndpoints {
  MyCardEndpoints._();

  /// 业务 API 根（登录 / authUser / 用户信息）。
  static const sapiBase = 'https://sapi.moecube.com:444';

  /// 账号密码直登端点（YGOMobile 同款；非 SSO 网页流程）。
  static const signInApiUrl = '$sapiBase/accounts/signin';

  /// u16Secret 获取端点（Bearer token）。
  static const authUserUrl = '$sapiBase/accounts/authUser';

  /// 用户公开信息（路径参数 {username}）。
  static const userApiTemplate = '$sapiBase/accounts/users/{username}.json';

  /// moecube 账号网页端根（注册 / 资料页 / SSO 都走网页流程，无 API）。
  static const accountsWebBase = 'https://accounts.moecube.com';

  /// 注册页（MyCard.URL_MC_SIGN_UP）：纯网页流程，宿主用 WebView/浏览器打开。
  static const signUpUrl = '$accountsWebBase/signup';

  /// 个人资料网页（MyCard.URL_MC_USER_PROFILE）。
  static const userProfileUrl = '$accountsWebBase/profiles';

  /// SSO 登录/登出页（MyCard.URL_MC_LOGOUT 同地址，登出靠 sso 参数）。
  static const ssoSignInUrl = '$accountsWebBase/signin';

  /// SSO 登出后的默认回跳地址（MyCard.mHomeUrl）。
  static const defaultSsoHomeUrl = 'https://mycard.world/mobile/';
}

/// 认证失败（网络错误 / 无效凭证 / 响应缺字段）。
class MyCardAuthException implements Exception {
  MyCardAuthException(this.message);

  final String message;

  @override
  String toString() => 'MyCardAuthException: $message';
}

/// MyCard 认证 API 客户端（无状态；登录态由调用方持有 [MyCardAccount]）。
class MyCardAuthService {
  MyCardAuthService({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// 单次请求超时。
  static const _timeout = Duration(seconds: 15);

  // ── 账号密码直登（非 SSO） ──────────────────────────────────────

  /// 用户名密码登录：`POST /accounts/signin`。
  ///
  /// 请求体（已核实 YGOMobile-cn-ko-en `LoginRequest`）：
  /// `{"account": <用户名>, "password": <密码>}` —— 字段名是 **account**。
  ///
  /// 成功响应真实形态（已核实 `LoginResponse`）：
  /// `{"token": "<JWT>", "success": true, "user": {"id": <int>, "username": "<显示名>"}}`
  /// —— token 在根级；user 包装对象只有 id 与 username 两个字段
  /// （login 响应的 user.username 即对决服用户名）。
  ///
  /// 失败语义：
  ///  - 401/403/422，或 HTTP 200 但 `success == false` → 用户名或密码错误；
  ///  - 其它非 200 → HTTP 错误；
  ///  - 超时/断网 → 网络错误。
  ///
  /// 响应形态容错：以真实形态优先，保留根级用户对象的兼容分支；
  /// token 字段兼容 `token` / `authentication_token` / `auth_token`。
  Future<MyCardAccount> signInWithPassword(
    String username,
    String password,
  ) async {
    final http.Response resp;
    try {
      resp = await _http
          .post(
            Uri.parse(MyCardEndpoints.signInApiUrl),
            headers: {'Content-Type': 'application/json'},
            // 权威规范：字段名为 account（非 username）。
            body: jsonEncode({'account': username, 'password': password}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw MyCardAuthException('网络超时，请稍后重试');
    } catch (e) {
      throw MyCardAuthException('网络错误：$e');
    }

    if (resp.statusCode == 401 ||
        resp.statusCode == 403 ||
        resp.statusCode == 422) {
      throw MyCardAuthException('用户名或密码错误');
    }
    if (resp.statusCode != 200) {
      throw MyCardAuthException('登录失败：HTTP ${resp.statusCode}');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException {
      throw MyCardAuthException('响应不是合法 JSON');
    }
    if (body is! Map) {
      throw MyCardAuthException('响应形态非法');
    }
    // API 语义：success == false 视为认证失败（即便 HTTP 200）。
    if (body['success'] == false) {
      throw MyCardAuthException('用户名或密码错误');
    }

    // token 在根级（真实形态）；兼容别名 authentication_token / auth_token。
    final token =
        (body['token'] ?? body['authentication_token'] ?? body['auth_token'])
            as String? ??
        '';
    if (token.isEmpty) {
      throw MyCardAuthException('响应缺少 token 字段');
    }

    // 真实形态：{"user": {"id": ..., "username": ...}} 包装；
    // 兼容分支：根级用户对象（旧容错逻辑）。
    final userMap = body['user'] is Map ? body['user'] as Map : body;
    final map = Map<String, dynamic>.of(userMap.cast<String, dynamic>());
    map['token'] = token;
    // avatar 字段兼容（字符串 URL 或 {"url": ...} 对象）。
    if (map['avatar_url'] == null) {
      final avatar = map['avatar'];
      if (avatar is String) {
        map['avatar_url'] = avatar;
      } else if (avatar is Map && avatar['url'] is String) {
        map['avatar_url'] = avatar['url'];
      }
    }
    map['username'] ??= username;
    return MyCardAccount.fromJson(map);
  }

  // ── u16Secret ─────────────────────────────────────────────────────

  /// 获取用户的 u16Secret（匹配与房间认证的时间轮换密钥，按需重新获取）。
  Future<int> fetchU16Secret(String token) async {
    console.log('MyCardAuthService.fetchU16Secret: token=$token');
    if (token.isEmpty) {
      throw MyCardAuthException('token 为空，请重新登录');
    }
    final resp = await _http
        .get(
          Uri.parse(MyCardEndpoints.authUserUrl),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw MyCardAuthException('获取 u16Secret 失败：HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    if (body is! Map || body['u16Secret'] is! num) {
      throw MyCardAuthException('响应缺少 u16Secret 字段');
    }
    final secret = (body['u16Secret'] as num).toInt();
    // 与 YGOMobile getUserU16Secret 一致：0 表示无效数据，按失败处理。
    if (secret == 0) {
      throw MyCardAuthException('获取 u16Secret 失败：返回数据无效');
    }
    return secret;
  }

  // ── 用户信息 ──────────────────────────────────────────────────────

  /// 查询用户公开信息；用户不存在返回 null。
  Future<MyCardAccount?> fetchUserInfo(String username) async {
    final url = MyCardEndpoints.userApiTemplate.replaceAll(
      '{username}',
      Uri.encodeComponent(username),
    );
    final resp = await _http.get(Uri.parse(url)).timeout(_timeout);
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    if (body is! Map || body['user'] is! Map) return null;
    return MyCardAccount.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
  }

  void dispose() => _http.close();
}
