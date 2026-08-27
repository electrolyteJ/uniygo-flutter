// ────────────────────────────────────────────────────────────
// Match Join Sheet
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:biz/service_singleton.dart';
import 'package:account_mycard/account_mycard.dart';
import '../../config/route.dart';
import '../../services/match_service.dart';
import '../../services/mycard_gate.dart';
import '../../widgets/create_room/room_dialog.dart';
import 'match_store.dart';

class MatchJoinSheet extends StatefulWidget {
  final GameServer server;
  const MatchJoinSheet({super.key, required this.server});

  @override
  State<MatchJoinSheet> createState() => _MatchJoinSheetState();
}

class _MatchJoinSheetState extends State<MatchJoinSheet> {
  final _usernameCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(BuildContext context) async {
    // MyCard 匹配服务需要登录（u16Secret 时间轮换密钥作 Basic 密钥）。
    final accountApi = context.read<MyCardAccountApi>();
    final account = await requireMyCardAccount(
      context,
      reason: widget.server.displayName,
    );
    if (account == null || !context.mounted) return;

    setState(() {
      _connecting = true;
      _error = null;
    });
    final matchStore = context.read<MatchStore>();
    final arena = widget.server.type == ServerType.matchAthletic
        ? 'athletic'
        : 'entertain';
    matchStore.startSearching(arena);
    Navigator.of(context).pop();

    try {
      final secret = await accountApi.fetchU16Secret();
      final result = await MatchService().match(
        arena: arena,
        username: account.username,
        secret: '$secret',
      );
      matchStore.setMatchResult(result.address, result.port, result.password);
      matchStore.setUsername(account.username);
      if (context.mounted) {
        context.go(DuelRoomRoute.current, extra: matchStore.toDuelRoomParams());
      }
      matchStore.reset();
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '匹配失败: $e';
        });
        matchStore.stopSearching();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: sheetContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.server.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.server.wsUrl}  ·  ${widget.server.description}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // 凭证来自 MyCard 登录态（u16Secret 密钥），无需手输密码。
            Builder(
              builder: (context) {
                final account = context.watch<MyCardAccountApi>().account;
                return darkTextField(
                  controller: _usernameCtrl
                    ..text = account?.username ?? _usernameCtrl.text,
                  label: account == null ? '用户名（登录后自动填充）' : '用户名',
                  icon: Icons.person,
                  readOnly: account != null,
                );
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            connectButton(
              label: '开始匹配',
              connecting: _connecting,
              onTapFeedback:
                  ServiceSingleton.instance.ygoSoundService.playButtonTap,
              onPressed: () => _join(context),
            ),
          ],
        ),
      ),
    );
  }
}
