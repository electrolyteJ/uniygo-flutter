// ── 加入房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import '../../config/servers.dart';
import 'password_field.dart';
import '../create_room/room_dialog.dart';

class JoinRoomForm extends StatefulWidget {
  final DuelEnvironment env;

  /// 加入成功后业务侧写 MatchStore + 跳转的回调（入参为已编码密码）。
  final ValueChanged<String> onJoin;

  /// 按钮点击反馈（如音效），由业务侧注入。
  final VoidCallback? onTapFeedback;

  const JoinRoomForm({
    super.key,
    required this.env,
    required this.onJoin,
    this.onTapFeedback,
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

  void _join() {
    final env = widget.env;

    // AI 本地人机对战：无需密码，直接进入（密码内容被 AiConnection 忽略）
    if (env.isAi) {
      setState(() {
        _connecting = true;
        _error = null;
      });
      widget.onJoin(RoomPassword.encodeJoin());
      return;
    }

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

    final password = env.usesRoomStringDsl
        ? pw
        : env.useEncodedPassword
        ? RoomPassword.encodeJoin(roomId: pw, secret: 0)
        : pw;
    widget.onJoin(password);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.env.isAi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            '与本地 AI 进行一场单局对战，无需联网。',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 16),
          connectButton(
            label: '开始人机对战',
            connecting: _connecting,
            onTapFeedback: widget.onTapFeedback,
            onPressed: _join,
          ),
        ],
      );
    }
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
            onSubmitted: (_) => _join(),
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
            onTapFeedback: widget.onTapFeedback,
            onPressed: _join,
          ),
        ],
      ),
    );
  }
}
