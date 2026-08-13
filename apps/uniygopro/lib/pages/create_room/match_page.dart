import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/match_service.dart';
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
    store.startSearching(arena);
    ServiceSingleton.instance.ygoSoundService.playMatchStart();

    try {
      final result = await _matchService.match(
        arena: arena,
        username: 'guest',
        secret: 'guest',
      );
      store.setMatchResult(result.address, result.port, result.password);
      ServiceSingleton.instance.ygoSoundService.playMatchFound();
      if (mounted) {
        context.go('/duel-room', extra: store.toDuelRoomParams());
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
