import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:account_mycard/account_mycard.dart';
import '../../config/route.dart';
import '../../services/match_service.dart';
import '../../services/mycard_gate.dart';
import 'package:biz/service_singleton.dart';

import 'match_store.dart';

class MatchPage extends StatefulWidget {
  const MatchPage({super.key});
  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _matchService = MatchService();

  Future<void> _startMatch(String arena) async {
    final store = context.read<MatchStore>();
    // 单飞守卫必须在登录门控之前：门控是 await（未登录时弹登录框，耗时
    // 数秒），期间按钮仍可点——per-State 的守卫曾在此窗口失守，两个流程
    // 完成后同帧两次 context.go('/duel-room') 撞车，触发
    // Navigator._debugLocked 断言崩溃（handlePush 过渡被取消）。
    if (!store.tryStartSearching(arena)) return;
    try {
      // MyCard 匹配服务需要登录（u16Secret 时间轮换密钥作 Basic 密钥）。
      final accountApi = context.read<MyCardAccountApi>();
      final account = await requireMyCardAccount(
        context,
        reason: '自动撮合匹配（天梯/休闲）',
      );
      if (account == null || !mounted) {
        store.stopSearching();
        return;
      }

      ServiceSingleton.instance.ygoSoundService.playMatchStart();

      try {
        final secret = await accountApi.fetchU16Secret();
        final result = await _matchService.match(
          arena: arena,
          username: account.username,
          secret: '$secret',
        );
        store.setMatchResult(result.address, result.port, result.password);
        ServiceSingleton.instance.ygoSoundService.playMatchFound();
        if (mounted) {
          context.go(Routes.duelRoom, extra: store.toDuelRoomParams());
          store.reset();
        }
      } catch (e) {
        store.stopSearching();
        ServiceSingleton.instance.ygoSoundService.playError();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('匹配失败: $e')),
          );
        }
      }
    } finally {
      // 成功路径由 setMatchResult/reset 收尾（isSearching=false）。
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ServiceSingleton.instance.ygoSoundService.playBackNavigation();
            context.go('/');
          },
        ),
        title: const Text('匹配对战'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: store.isSearching
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在搜索对手...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _startMatch('athletic'),
                    child: const Text('竞技匹配'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _startMatch('entertain'),
                    child: const Text('娱乐匹配'),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _matchService.dispose();
    super.dispose();
  }
}
