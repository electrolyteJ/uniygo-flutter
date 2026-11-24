/// 独立登录页：MyCard 账号密码直登（不走网页 SSO），支持游客跳过。
///
/// 两种进入方式：
/// - 冷启首屏：开屏页分流而来，`extra` 可为空，登录成功或游客进入都 `go` 到大厅；
/// - 门控跳转：`requireMyCardAccount` 以 `push` 打开并携带 `from`，
///   成功后 `pop(account)` 把账号交回调用方，取消/游客进入则 `pop(null)`。
library;

import 'dart:convert';

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/route.dart';
import '../layout/app_layout.dart';
// `kMycardCredentialsKey` 定义在 dialog 里（更老、也被 mycard_gate 消费），
// 此处只 import 复用，不再重复定义同名顶层常量——两处各定义一份时，任何
// 同时 import 这两个库的文件都会直接编译报错。
import '../widgets/mycard_login_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.from, this.reason});

  /// 登录成功后要回到的路由；为空时回大厅。
  final String? from;

  /// 触发登录的原因提示（门控跳转时展示）。
  final String? reason;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  bool _obscure = true;
  bool _rememberPassword = true; // 默认勾选“记住密码”
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// 启动时从 SharedPreferences 读取已保存凭证，预填到输入框。
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kMycardCredentialsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map;
      final username = map['username'] as String? ?? '';
      final password = map['password'] as String? ?? '';
      if (username.isEmpty || password.isEmpty) return;
      _usernameCtrl.text = username;
      _passwordCtrl.text = password;
      _rememberPassword = true;
      if (mounted) setState(() {});
    } on FormatException {
      // 损坏的凭证数据，清除避免反复出错。
      await prefs.remove(kMycardCredentialsKey);
    }
  }

  /// 登录成功后根据勾选状态保存或清除凭证。
  Future<void> _persistCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberPassword) {
      await prefs.setString(
        kMycardCredentialsKey,
        jsonEncode({'username': username, 'password': password}),
      );
    } else {
      await prefs.remove(kMycardCredentialsKey);
    }
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入用户名和密码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final account = await context.read<MyCardAccountApi>().signIn(
        username,
        password,
      );
      // 登录成功后再落盘凭证（避免存错密码）。
      await _persistCredentials(username, password);
      if (!mounted) return;
      _leave(account);
    } on MyCardAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '登录失败：$e';
      });
    }
  }

  /// 离开登录页：可回退（门控 push）时把账号交回调用方，否则跳大厅。
  void _leave(MyCardAccount? account) {
    if (context.canPop()) {
      context.pop(account);
    } else {
      context.go(widget.from ?? Routes.home);
    }
  }

  void _enterAsGuest() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.from ?? Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final wide = spec.tier == AppLayoutTier.wide;
    // compact 下表单占满整宽且高于视口，其滚动区会盖住顶部两个按钮——
    // 按钮虽仍可见却点不到（游客进入失效，首启链路断在登录页）。
    // 因此：① 表单区为顶部按钮留出 56px；② 顶部按钮排在 Stack 末尾，
    // 保证绘制与命中都在表单之上。
    final compact = spec.tier == AppLayoutTier.compact;
    final topBarInset = compact ? 56.0 : spec.pagePadding * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: wide
                  ? SizedBox(
                      width: spec.maxContentWidth,
                      child: Row(
                        children: [
                          Expanded(
                            child: _BrandPanel(
                              spec: spec,
                              reason: widget.reason,
                            ),
                          ),
                          SizedBox(
                            width: 420 + spec.pagePadding * 2,
                            child: Center(
                              child: SizedBox(
                                width: 420,
                                child: _buildForm(spec),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? double.infinity : 420,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          spec.pagePadding,
                          topBarInset,
                          spec.pagePadding,
                          spec.pagePadding * 1.5,
                        ),
                        child: SingleChildScrollView(child: _buildForm(spec)),
                      ),
                    ),
            ),
            Positioned(
              left: spec.pagePadding,
              top: spec.pagePadding * 0.4,
              child: IconButton(
                key: const ValueKey('login-back'),
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF8A93A8),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.home);
                  }
                },
              ),
            ),
            Positioned(
              right: spec.pagePadding,
              top: spec.pagePadding * 0.4,
              child: TextButton(
                key: const ValueKey('login-guest-entry'),
                onPressed: _submitting ? null : _enterAsGuest,
                child: const Text(
                  '游客进入',
                  style: TextStyle(color: Color(0xFF37E2FF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppLayoutSpec spec) {
    final compact = spec.tier == AppLayoutTier.compact;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec.tier != AppLayoutTier.wide) ...[
          const Text(
            '登录 MyCard 账号',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.reason ?? '登录后可参与竞技匹配与卡组上传，游客可先体验本地对战',
            style: const TextStyle(color: Color(0xFF8A93A8), fontSize: 12),
          ),
          SizedBox(height: spec.gutter),
        ],
        TextField(
          key: const ValueKey('mycard-login-username'),
          controller: _usernameCtrl,
          enabled: !_submitting,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: const InputDecoration(
            labelText: '用户名',
            prefixIcon: Icon(Icons.person_outline),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('mycard-login-password'),
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          enabled: !_submitting,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '密码',
            prefixIcon: const Icon(Icons.lock_outline),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            key: const ValueKey('mycard-login-error'),
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Checkbox(
              key: const ValueKey('mycard-login-remember'),
              value: _rememberPassword,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _rememberPassword = v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _submitting
                    ? null
                    : () =>
                          setState(() => _rememberPassword = !_rememberPassword),
                child: const Text(
                  '记住密码（仅本机，下次自动填入）',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A93A8)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spec.gutter),
        SizedBox(
          height: compact ? 48 : 52,
          child: FilledButton(
            key: const ValueKey('mycard-login-submit'),
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF37E2FF),
              foregroundColor: const Color(0xFF05202A),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF05202A),
                    ),
                  )
                : const Text('登录'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting ? null : () => context.go(Routes.home),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// wide 档左侧品牌视觉。
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.spec, this.reason});

  final AppLayoutSpec spec;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(spec.pagePadding * 1.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino, color: Color(0xFFFFD75A), size: 36),
              const SizedBox(width: 12),
              const Text(
                'uniygo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: spec.gutter),
          const Text(
            '登录 MyCard 账号',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reason ?? '同步天梯排名、卡组广场与云端卡组，跨设备继续你的决斗。',
            style: const TextStyle(color: Color(0xFF8A93A8), fontSize: 13),
          ),
          SizedBox(height: spec.gutter * 1.5),
          for (final line in const [
            '竞技 / 娱乐自动撮合',
            '卡组广场一键导入',
            '云端卡组同步',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF37E2FF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    line,
                    style: const TextStyle(
                      color: Color(0xFFB9C4D6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
