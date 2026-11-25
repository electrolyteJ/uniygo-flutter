/// 02 登录：MyCard 账号密码 / 游客分流。
///
/// 设计稿：Ardot 744179416852082 页面「02 登录」（844×390）。
/// 真实登录走 account_mycard 的 [MyCardAccountApi.signIn]（POST /accounts/signin），
/// 「记住账号」只持久化用户名到 SharedPreferences，不保存密码。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/route.dart';
import '../ui/duel_canvas.dart';
import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import '../util/snack_bar_util.dart';

/// 「记住账号」持久化的用户名键（不保存密码）。
const String kRememberedUsernameKey = 'mycard_login_username';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  SharedPreferences? _prefs;
  bool _remember = true;
  bool _busy = false;
  bool _qrHintShown = false;

  @override
  void initState() {
    super.initState();
    _restoreRemembered();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _restoreRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      final saved = prefs.getString(kRememberedUsernameKey);
      if (saved != null && saved.isNotEmpty) {
        _username.text = saved;
        _remember = true;
      }
    });
  }

  void _tap() => DuelSounds.tap();

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty) {
      showSnackBar(context, '请输入 MyCard 用户名');
      return;
    }
    if (password.isEmpty) {
      showSnackBar(context, '请输入密码');
      return;
    }

    _tap();
    setState(() => _busy = true);
    final api = context.read<MyCardAccountApi>();
    try {
      final account = await api.signIn(username, password);
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString(kRememberedUsernameKey, username);
      } else {
        await prefs.remove(kRememberedUsernameKey);
      }
      if (!mounted) return;
      DuelSounds.success();
      showSnackBar(context, '欢迎，${account.displayName}');
      context.go(Routes.home);
    } on MyCardAuthException catch (e) {
      if (!mounted) return;
      DuelSounds.error();
      showSnackBar(context, '登录失败：${e.message}');
    } catch (e) {
      if (!mounted) return;
      DuelSounds.error();
      showSnackBar(context, '登录失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterAsGuest() {
    _tap();
    DuelSounds.homeEnter();
    context.go(Routes.home);
  }

  void _backToSplash() {
    _tap();
    context.go(Routes.splash);
  }

  void _onQrTab() {
    if (_qrHintShown) return;
    _qrHintShown = true;
    _tap();
    showSnackBar(context, '扫码登录即将开放，请先用账号密码登录');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuelColors.base,
      resizeToAvoidBottomInset: false,
      body: DuelStage(
        backdrop: DuelBackdropKind.login,
        child: Stack(
          children: [
            _brand(),
            _seasonLabel(),
            _loginCard(),
            _stats(),
            _serviceStatus(),
          ],
        ),
      ),
    );
  }

  // ── 左上品牌 ────────────────────────────────────────────────────
  Widget _brand() {
    return Positioned(
      left: 30,
      top: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'uniy',
            style: DuelType.serif(22, height: 1.2, letterSpacing: -0.2),
          ),
          Text(
            'go',
            style: DuelType.serif(
              22,
              height: 1.2,
              letterSpacing: -0.2,
              color: DuelColors.accent,
            ),
          ),
          const SizedBox(width: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '决斗终端 · DUEL TERMINAL',
              style: DuelType.latin(9.5, color: DuelColors.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonLabel() {
    return Positioned(
      right: 18,
      top: 30,
      child: Text(
        'SEASON 14 · ARRIVAL',
        style: DuelType.latin(
          9.5,
          color: DuelColors.textDim,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  // ── 登录卡片 ────────────────────────────────────────────────────
  Widget _loginCard() {
    return Positioned(
      left: 243,
      top: 18.5,
      width: 357,
      height: 348,
      child: Container(
        decoration: BoxDecoration(
          color: DuelColors.panel,
          border: Border.all(color: DuelColors.border),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 21,
              top: 8,
              child: Text('账号登录', style: DuelType.serif(24, height: 1.15)),
            ),
            Positioned(
              left: 21,
              top: 46,
              child: Text(
                '使用 MyCard 账号进入主页',
                style: DuelType.sans(10.5, color: DuelColors.textDim),
              ),
            ),
            _myCardBadge(),
            _tabs(),
            // 用户名
            Positioned(
              left: 21,
              top: 101,
              child: Text(
                '用户名',
                style: DuelType.sans(10.5, color: DuelColors.textDim),
              ),
            ),
            Positioned(
              left: 21,
              top: 119,
              width: 314,
              height: 31,
              child: _DuelInput(
                key: const ValueKey('login-username'),
                controller: _username,
                hint: '请输入 MyCard 用户名',
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
            ),
            // 密码
            Positioned(
              left: 21,
              top: 161,
              child: Text(
                '密码',
                style: DuelType.sans(10.5, color: DuelColors.textDim),
              ),
            ),
            Positioned(
              left: 21,
              top: 176,
              width: 314,
              height: 31,
              child: _DuelInput(
                key: const ValueKey('login-password'),
                controller: _password,
                hint: '请输入密码',
                obscure: true,
                enabled: !_busy,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            // 记住账号 / 忘记密码
            Positioned(
              left: 21,
              top: 222,
              child: DuelHit(
                onTap: _busy
                    ? null
                    : () {
                        _tap();
                        setState(() => _remember = !_remember);
                      },
                child: Row(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: _remember
                            ? DuelColors.accent
                            : Colors.transparent,
                        border: Border.all(
                          color: _remember
                              ? DuelColors.accent
                              : DuelColors.borderSoft,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _remember
                          ? const Text(
                              '✓',
                              style: TextStyle(
                                fontSize: 9,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: DuelColors.inkOnAccent,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '记住账号',
                      style: DuelType.sans(
                        11,
                        color: DuelColors.textMuted,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 22,
              top: 220,
              child: DuelHit(
                onTap: () => showSnackBar(context, '请前往 MyCard 账号站点重置密码'),
                child: Text(
                  '忘记密码?',
                  style: DuelType.sans(11, color: DuelColors.textDim),
                ),
              ),
            ),
            // 登录 / 游客
            Positioned(
              left: 21,
              top: 243,
              width: 314,
              height: 41,
              child: _primaryButton(
                key: const ValueKey('login-submit'),
                label: _busy ? '登录中…' : '登 录',
                onTap: _busy ? null : _submit,
              ),
            ),
            Positioned(
              left: 21,
              top: 291,
              width: 314,
              height: 38,
              child: DuelHit(
                key: const ValueKey('login-guest'),
                onTap: _busy ? null : _enterAsGuest,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: DuelColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '游客进入主页',
                    style: DuelType.sans(13, color: DuelColors.textBody),
                  ),
                ),
              ),
            ),
            // 脚注
            Positioned(
              left: 21,
              top: 332,
              child: Text.rich(
                TextSpan(
                  style: DuelType.sans(8.6, color: DuelColors.textFaint),
                  children: [
                    const TextSpan(text: '游客可用 '),
                    TextSpan(
                      text: '自由房间 / AI 对决 / 残局房',
                      style: TextStyle(color: DuelColors.gold),
                    ),
                    const TextSpan(text: '，竞技需登录'),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 22,
              top: 332,
              child: DuelHit(
                onTap: _backToSplash,
                child: Text(
                  '← 返回开屏',
                  style: DuelType.sans(8.6, color: DuelColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myCardBadge() {
    return Positioned(
      left: 262,
      top: 16,
      width: 66,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1E3A4E)),
        ),
        alignment: Alignment.center,
        child: Text(
          'MYCARD',
          style: DuelType.latin(
            9,
            color: const Color(0xFF7FA8C0),
            weight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    return Positioned(
      left: 21,
      top: 70,
      right: 22,
      child: SizedBox(
        height: 24,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Text(
                '账号密码',
                style: DuelType.sans(
                  13,
                  color: DuelColors.textPrimary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              left: 71,
              top: 0,
              child: DuelHit(
                onTap: _onQrTab,
                child: Text(
                  '扫码登录',
                  style: DuelType.sans(13, color: DuelColors.textGhost),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 21,
              child: Container(width: 54, height: 2, color: DuelColors.accent),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 22,
              child: Container(height: 1, color: DuelColors.divider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    Key? key,
    required String label,
    required VoidCallback? onTap,
  }) {
    return DuelHit(
      key: key,
      onTap: onTap,
      child: Container(
        color: DuelColors.accent,
        alignment: Alignment.center,
        child: _busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DuelColors.inkOnAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: DuelType.sans(
                      13,
                      color: DuelColors.inkOnAccent,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: DuelType.sans(
                  15,
                  color: DuelColors.inkOnAccent,
                  weight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }

  // ── 底部统计 / 服务状态 ────────────────────────────────────────
  Widget _stats() {
    return Positioned(
      left: 30,
      bottom: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stat('20114', '可用卡牌', rightPadding: 20),
          Container(width: 1, height: 26, color: DuelColors.divider),
          const SizedBox(width: 14),
          _stat('8', '对战模式', rightPadding: 20),
          Container(width: 1, height: 26, color: DuelColors.divider),
          const SizedBox(width: 14),
          _stat('38 ms', '当前延迟'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {double rightPadding = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: DuelType.latin(
              15,
              height: 1.15,
              color: DuelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: DuelType.sans(9, height: 1.1, color: DuelColors.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatus() {
    return Positioned(
      right: 18,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '卡表校验完成 · 在线',
            style: DuelType.sans(9.5, color: DuelColors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            'MYCARD 通行服务运行中',
            style: DuelType.sans(9.5, color: DuelColors.textGhost),
          ),
        ],
      ),
    );
  }
}

/// 深色输入框（设计稿：314×31、#071019 底、#1A2C3E 描边，聚焦转青）。
class _DuelInput extends StatefulWidget {
  const _DuelInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_DuelInput> createState() => _DuelInputState();
}

class _DuelInputState extends State<_DuelInput> {
  FocusNode? _ownedFocus;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DuelColors.field,
        border: Border.all(
          color: _focused ? DuelColors.accentDim : DuelColors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        obscureText: widget.obscure,
        obscuringCharacter: '●',
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        inputFormatters: [
          LengthLimitingTextInputFormatter(widget.obscure ? 128 : 64),
        ],
        cursorColor: DuelColors.accent,
        cursorWidth: 1,
        style: DuelType.latin(
          widget.obscure ? 12 : 14,
          color: DuelColors.textBody,
          height: 1,
          letterSpacing: widget.obscure ? 1.2 : 0,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: DuelType.sans(11, color: DuelColors.textGhost, height: 1),
        ),
      ),
    );
  }
}
