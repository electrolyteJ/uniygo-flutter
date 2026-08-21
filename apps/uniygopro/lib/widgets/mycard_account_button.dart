/// MyCard 账号入口按钮（首页 AppBar）：未登录显示登录图标，
/// 已登录显示用户名首字头像，点击弹出登录/登出菜单。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_mycard/account_mycard.dart';

import '../services/mycard_gate.dart';

class MyCardAccountButton extends StatelessWidget {
  const MyCardAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<MyCardAccountApi>();
    final account = api.account;
    return IconButton(
      tooltip: account == null ? '登录 MyCard' : '${account.displayName}（已登录）',
      icon: account == null
          ? const Icon(Icons.account_circle_outlined)
          : CircleAvatar(
              radius: 12,
              child: Text(
                account.displayName.isEmpty
                    ? '?'
                    : account.displayName.characters.first,
                style: const TextStyle(fontSize: 12),
              ),
            ),
      onPressed: () => _onTap(context, api),
    );
  }

  Future<void> _onTap(BuildContext context, MyCardAccountApi api) async {
    if (api.isLoggedIn) {
      // 已登录：底部弹账号操作（查看/登出）。
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) {
          final account = api.account!;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(account.displayName),
                  subtitle: Text('@${account.username}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => Navigator.of(ctx).pop('signOut'),
                ),
              ],
            ),
          );
        },
      );
      if (action == 'signOut' && context.mounted) {
        api.signOut(); // 纯本地清登录态（无服务端登出 API）
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已退出 MyCard 登录')));
      }
      return;
    }
    // 未登录：走门控流程（应用内账号密码直登）。
    if (!context.mounted) return;
    await requireMyCardAccount(context, reason: '登录后可使用 MyCard 对战服务');
  }
}
