/// MyCard 登录态持有（ChangeNotifier，供 UI 层监听与持久化）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mycard_account.dart';

/// 登录态仓库：内存持有当前账号，可选 JSON 字符串持久化
/// （持久化介质由宿主注入——shared_preferences / ygo_storage 等）。
class MyCardAccountStore extends ChangeNotifier {
  MyCardAccountStore({String? persistedJson}) {
    if (persistedJson != null && persistedJson.isNotEmpty) {
      try {
        _account = MyCardAccount.fromJson(
          (jsonDecode(persistedJson) as Map).cast<String, dynamic>(),
        );
      } on FormatException {
        _account = null; // 损坏的持久化数据按未登录处理
      }
    }
  }

  MyCardAccount? _account;

  /// 当前登录账号；未登录为 null。
  MyCardAccount? get account => _account;

  /// 是否已登录。
  bool get isLoggedIn => _account != null;

  /// 登录成功入库。
  void signIn(MyCardAccount account) {
    _account = account;
    notifyListeners();
  }

  /// 登出清空。
  void signOut() {
    _account = null;
    notifyListeners();
  }

  /// 序列化为 JSON 字符串（供宿主持久化）。
  String? toPersistedJson() =>
      _account == null ? null : jsonEncode(_account!.toJson());
}
