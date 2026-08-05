// ── 加入房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';

import '../../config/servers.dart';
import '../../pages/create_room/match_store.dart';
import '../shared/create_room.dart';

class JoinRoomForm extends StatefulWidget {
  final GameServer server;
  final DuelEnvironment env;
  const JoinRoomForm({
    super.key,
    required this.server,
    required this.env,
  });

  @override
  State<JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends State<JoinRoomForm> {
  final _pwCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void didUpdateWidget(covariant JoinRoomForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.env.usesRoomStringDsl != widget.env.usesRoomStringDsl) {
      _error = null;
    }
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(BuildContext context) async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) {
      setState(
        () => _error = widget.env.usesRoomStringDsl ? '请输入房间串' : '请输入房间密码',
      );
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final matchStore = context.read<MatchStore>();
    final server = widget.server;
    final env = widget.env;

    final password = env.usesRoomStringDsl
        ? pw
        : env.useEncodedPassword
        ? RoomPassword.encodeJoin(roomId: pw, secret: 0)
        : pw;
    matchStore.selectServer(server, env, password);
    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          PasswordField(
            controller: _pwCtrl,
            label: widget.env.usesRoomStringDsl ? '房间串 / 房间密码' : '房间密码',
            hintText: widget.env.usesRoomStringDsl
                ? '例如 M#房名 或 OT,MR5#房名'
                : null,
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
          const SizedBox(height: 16),
          connectButton(
            label: '加入房间',
            connecting: _connecting,
            onPressed: () => _join(context),
          ),
        ],
      ),
    );
  }
}
