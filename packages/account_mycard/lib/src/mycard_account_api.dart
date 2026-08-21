/// MyCard 账号体系统一门面：把 [MyCardAuthService]（无状态 API 客户端）与
/// [MyCardAccountStore]（登录态持有）组合成单一入口，对外提供全部账号能力。
///
/// 能力一览（规范均核实自 YGOMobile-cn-ko-en 源码）：
///  - 登录：[signIn]（POST /accounts/signin，成功自动写入登录态并通知）；
///  - 退出登录：[signOut]（纯本地清登录态，无服务端 API；
///    有网页 SSO 会话时可用 [getSsoLogoutUrl] 构造登出地址）；
///  - 注册：无 API，网页流程，宿主用 WebView/浏览器打开 [signUpUrl]；
///  - 个人信息：[fetchProfile]（公开信息 API）/ [userProfileUrl]（资料网页）；
///  - u16Secret：[fetchU16Secret]（匹配/房间认证密钥，用当前登录态 token）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mycard_account.dart';
import 'mycard_account_store.dart';
import 'mycard_auth_service.dart';

/// MyCard 账号体系统一接口（ChangeNotifier，可直接作为 Provider 注入）。
class MyCardAccountApi extends ChangeNotifier {
  MyCardAccountApi({
    MyCardAuthService? authService,
    MyCardAccountStore? store,
    String? persistedJson,
  }) : _auth = authService ?? MyCardAuthService(),
       _store = store ?? MyCardAccountStore(persistedJson: persistedJson) {
    // 登录态变化原样转发给门面监听者（持久化回写、UI 刷新）。
    _store.addListener(notifyListeners);
  }

  final MyCardAuthService _auth;
  final MyCardAccountStore _store;

  // ── 网页流程常量（无 API，宿主用 WebView/浏览器打开） ─────────────

  /// 注册页 URL（https://accounts.moecube.com/signup）。
  static const String signUpUrl = MyCardEndpoints.signUpUrl;

  /// 个人资料网页 URL（https://accounts.moecube.com/profiles）。
  static const String userProfileUrl = MyCardEndpoints.userProfileUrl;

  // ── 登录态 ───────────────────────────────────────────────────────

  /// 当前登录账号；未登录为 null。
  MyCardAccount? get account => _store.account;

  /// 是否已登录。
  bool get isLoggedIn => _store.isLoggedIn;

  /// 序列化当前登录态（供宿主持久化）；未登录返回 null。
  String? toPersistedJson() => _store.toPersistedJson();

  // ── 登录 / 退出 ──────────────────────────────────────────────────

  /// 用户名密码登录（POST /accounts/signin，字段名 account）。
  ///
  /// 成功：写入登录态并通知监听者，返回账号。
  /// 失败：抛 [MyCardAuthException]（消息可直接展示），登录态不变。
  Future<MyCardAccount> signIn(String username, String password) async {
    final account = await _auth.signInWithPassword(username.trim(), password);
    _store.signIn(account);
    return account;
  }

  /// 退出登录：纯本地清除登录态并通知监听者（无服务端 API，
  /// 对应 YGOMobile MycardFragment.performLogout 的清空逻辑；
  /// 断开对决服务连接由宿主自行处理）。
  ///
  /// 若宿主内嵌过 moecube 网页 SSO 会话，可另开 [getSsoLogoutUrl]
  /// 清理网页会话；纯 API 登录场景调用本方法即可。
  void signOut() => _store.signOut();

  /// 构造 SSO 网页登出地址（MyCard.getMCLogoutUrl 同款）：
  /// `https://accounts.moecube.com/signin?sso=<base64("return_sso_url=" + urlencode(homeUrl))>`
  ///
  /// 仅用于清理网页 SSO 会话（如宿主内嵌 WebView 登录过账号站点）；
  /// 纯 API 登录的登出见 [signOut]。
  static String getSsoLogoutUrl({
    String homeUrl = MyCardEndpoints.defaultSsoHomeUrl,
  }) {
    final payload = 'return_sso_url=${Uri.encodeComponent(homeUrl)}';
    final sso = base64Encode(utf8.encode(payload));
    return Uri.parse(MyCardEndpoints.ssoSignInUrl)
        .replace(queryParameters: {'sso': sso})
        .toString();
  }

  // ── 个人信息 / 密钥 ───────────────────────────────────────────────

  /// 查询用户公开个人信息（GET /accounts/users/{username}.json）；
  /// 用户不存在返回 null。
  Future<MyCardAccount?> fetchProfile(String username) =>
      _auth.fetchUserInfo(username);

  /// 获取当前登录账号的 u16Secret（匹配与房间认证的时间轮换密钥，
  /// 按需重新获取）。未登录 / token 为空抛 [MyCardAuthException]。
  Future<int> fetchU16Secret() => _auth.fetchU16Secret(account?.token ?? '');

  // ── 生命周期 ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _auth.dispose();
    _store.dispose();
    super.dispose();
  }
}
