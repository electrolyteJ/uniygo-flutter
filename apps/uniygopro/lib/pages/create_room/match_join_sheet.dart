// ────────────────────────────────────────────────────────────
// Match Join Sheet
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:duel_room1/service_singleton.dart';
import '../../services/match_service.dart';
import '../../widgets/create_room/room_dialog.dart';
import 'match_store.dart';

class MatchJoinSheet extends StatefulWidget {
  final GameServer server;
  const MatchJoinSheet({super.key, required this.server});

  @override
  State<MatchJoinSheet> createState() => _MatchJoinSheetState();
}

class _MatchJoinSheetState extends State<MatchJoinSheet> {
  final _usernameCtrl = TextEditingController(text: 'Guest');
  final _passwordCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(BuildContext context) async {
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
      final result = await MatchService().match(
        arena: arena,
        username: _usernameCtrl.text.trim(),
        secret: _passwordCtrl.text.trim(),
      );
      matchStore.setMatchResult(result.address, result.port, result.password);
      matchStore.setUsername(_usernameCtrl.text.trim());
      if (context.mounted) {
        context.go('/duel-room', extra: matchStore.toDuelRoomParams());
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
            darkTextField(
              controller: _usernameCtrl,
              label: '用户名',
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _passwordCtrl,
              label: '密码 (选填)',
              hintText: '留空使用默认密码',
              icon: Icons.lock,
              onSubmitted: (_) => _join(context),
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
