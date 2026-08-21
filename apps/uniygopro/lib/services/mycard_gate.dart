/// MyCard 登录门控：对决服务需要 MyCard 认证时统一走这里。
///
/// 已登录 → 直接返回当前账号；未登录 → 弹出应用内账号密码登录
/// 对话框（直调 `/accounts/signin`，不走网页 SSO）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_mycard/account_mycard.dart';

import '../widgets/mycard_login_dialog.dart';

/// 要求 MyCard 登录态。
///
/// 返回当前账号；用户取消/登录失败返回 null（调用方中止后续操作）。
Future<MyCardAccount?> requireMyCardAccount(
  BuildContext context, {
  String? reason,
}) async {
  final api = context.read<MyCardAccountApi>();
  final existing = api.account;
  if (existing != null) return existing;

  final messenger = ScaffoldMessenger.of(context);
  // 对话框内走统一接口登录，成功即自动写入登录态（并通知监听者）。
  final account = await showMyCardLoginDialog(context, reason: reason, api: api);
  if (account == null) return null; // 用户取消

  messenger.showSnackBar(SnackBar(content: Text('欢迎，${account.displayName}')));
  return account;
}
