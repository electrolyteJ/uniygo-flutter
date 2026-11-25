/// 匹配页签的业务逻辑：单飞守卫 → 登录门控 → u16Secret → /ygopro/match → 进房。
///
/// 从 [CreateRoomPage] 抽出，页面只负责把 [matching] / [elapsed] 画到匹配盘上。
library;

import 'dart:async';
import 'dart:developer' as console;

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/route.dart';
import '../../login/mycard_gate.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import '../../util/snack_bar_util.dart';
import '../services/match_service.dart';

/// 匹配流程控制器（ChangeNotifier，页面监听后 setState）。
class MatchController extends ChangeNotifier {
  bool _matching = false;
  int _elapsed = 0;
  MatchService? _service;
  Timer? _elapsedTimer;

  /// 取消 / 重入令牌：回调回来时若已不是当前这一轮，直接丢弃。
  int _token = 0;

  bool get matching => _matching;
  int get elapsed => _elapsed;

  /// 开始匹配。[arena] 取 athletic / entertain；[title] 用于登录门控文案。
  Future<void> start(
    BuildContext context, {
    required String arena,
    required String title,
  }) async {
    if (_matching) return;
    // await 之后页面/弹层可能已卸载，先把路由与 API 取出来。
    final router = GoRouter.of(context);
    final api = context.read<MyCardAccountApi>();
    final token = ++_token;

    _beginMatching();
    DuelSounds.matchStart();

    try {
      final account = await requireMyCardAccount(context, reason: title);
      if (account == null || token != _token) {
        _finishMatching();
        return;
      }
      final service = MatchService();
      _service = service;
      final secret = await api.fetchU16Secret();
      final result = await service.match(
        arena: arena,
        username: account.username,
        secret: '$secret',
      );
      if (token != _token) return;
      service.dispose();
      _service = null;
      _finishMatching();
      DuelSounds.matchFound();
      int port = -1;
      // websocket 连接8912/7912；socket连接8911/7911
      if (arena == "athletic") {
        port = 8912;
      } else {
        port = 7912;
      }
      router.go(Routes.duelRoom, extra: <String, Object?>{
        'uri': Uri.tryParse('wss://${result.address}:$port'),
        'serverPassword': result.password,
        'username': account.username,
        'roomName': '匹配房',
      });
    } catch (e) {
      if (token != _token) return;
      _service?.dispose();
      _service = null;
      _finishMatching();
      DuelSounds.error();
      if (context.mounted) {
        showSnackBar(context, '匹配失败：$e');
      }
    }
  }

  /// 取消匹配：关掉在途客户端并复位。
  void cancel() {
    _token++;
    _service?.dispose();
    _service = null;
    _finishMatching();
    DuelSounds.dialogClose();
  }

  void _beginMatching() {
    _matching = true;
    _elapsed = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      notifyListeners();
    });
    notifyListeners();
  }

  void _finishMatching() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _matching = false;
    _elapsed = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _service?.dispose();
    super.dispose();
  }
}
