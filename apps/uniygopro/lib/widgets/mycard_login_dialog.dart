/// MyCard 账号密码登录对话框（应用内直登，不走网页 SSO）。
library;

import 'package:flutter/material.dart';
import 'package:account_mycard/account_mycard.dart';

/// 弹出登录表单；成功返回账号（已通过统一接口写入登录态），取消返回 null。
Future<MyCardAccount?> showMyCardLoginDialog(
  BuildContext context, {
  String? reason,
  MyCardAccountApi? api,
}) {
  return showDialog<MyCardAccount>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _MyCardLoginDialog(reason: reason, api: api ?? MyCardAccountApi()),
  );
}

class _MyCardLoginDialog extends StatefulWidget {
  const _MyCardLoginDialog({this.reason, required this.api});

  final String? reason;
  final MyCardAccountApi api;

  @override
  State<_MyCardLoginDialog> createState() => _MyCardLoginDialogState();
}

class _MyCardLoginDialogState extends State<_MyCardLoginDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
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
      final account = await widget.api.signIn(username, password);
      if (!mounted) return;
      Navigator.of(context).pop(account);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录 MyCard 账号'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.reason != null) ...[
              Text(
                widget.reason!,
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
              ),
              const SizedBox(height: 12),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('mycard-login-submit'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
      ],
    );
  }
}
