// ── 加入房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_mycard/account_mycard.dart';

import '../../config/servers.dart';
import '../../services/mycard_gate.dart';
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

  Future<void> _join() async {
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
        () => _error = widget.env.usesRoomStringDsl
            ? '请输入房间串'
            : widget.env.useEncodedPassword
            ? '请输入朋友私密房间 ID'
            : '请输入房间密码',
      );
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    // MyCard 私密房：登录门禁 + 重新获取 u16Secret + joinPrivate 编码。
    if (env.useEncodedPassword) {
      await _joinMyCard(pw);
      return;
    }

    widget.onJoin(pw);
  }

  /// 加入 MyCard 私密房（对齐 neos-ts Match/index.tsx onJoinMCRoom）：
  /// 朋友告知私密房数字 ID（由房主 external_id 派生），登录门禁后每次
  /// 操作前重新获取 u16Secret（时间轮换密钥），按 joinPrivate 编码。
  Future<void> _joinMyCard(String roomId) async {
    try {
      final account = await requireMyCardAccount(
        context,
        reason: '加入 MyCard 私密房间',
      );
      if (account == null) {
        // 用户取消登录
        if (mounted) setState(() => _connecting = false);
        return;
      }
      if (!mounted) return;
      final u16Secret = await context.read<MyCardAccountApi>().fetchU16Secret();
      widget.onJoin(
        RoomPassword.encodeJoin(
          roomId: roomId,
          secret: u16Secret,
          isPrivate: true,
        ),
      );
    } on MyCardAuthException catch (e) {
      // u16Secret 获取失败（如登录过期），消息可直接展示
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '加入房间失败：$e';
        });
      }
    }
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
          // MyCard 私密房：输入朋友分享的数字房间 ID（无需遮蔽）。
          if (widget.env.useEncodedPassword)
            darkTextField(
              controller: _pwCtrl,
              label: '朋友私密房间 ID',
              hintText: '朋友建房后分享的数字房间 ID',
              icon: Icons.tag,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _join(),
            )
          else
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
