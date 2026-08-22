// ────────────────────────────────────────────────────────────
// Spectate Room Sheet（观战面板：实时列出进行中的对局，点击进入观战）
// ────────────────────────────────────────────────────────────

import 'package:account_mycard/account_mycard.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:biz/service_singleton.dart';
import 'package:uniygopro/config/servers.dart';
import '../../services/mycard_gate.dart';
import '../../services/spectate_service.dart';
import '../../widgets/create_room/room_dialog.dart';
import 'match_store.dart';

/// 观战面板：连接观战列表 WebSocket，实时展示进行中的对局；
/// 点击某个房间即以观战者身份进入（复用 duel_room1 的观战渲染链路）。
class SpectateRoomSheet extends StatefulWidget {
  final GameServer server;
  const SpectateRoomSheet({super.key, required this.server});

  @override
  State<SpectateRoomSheet> createState() => _SpectateRoomSheetState();
}

class _SpectateRoomSheetState extends State<SpectateRoomSheet> {
  late final SpectateService _service;

  @override
  void initState() {
    super.initState();
    _service = SpectateService(
      host: widget.server.host,
      port: widget.server.port,
    )..connect();
    _service.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    _service.dispose();
    super.dispose();
  }

  /// 进入观战：连到对应匹配服，以房间 id 编码后的密码加入（对局中后进者
  /// 由服务端置为观战者）。
  ///
  /// 密码编码对齐 YGOMobile `getWatchDuelPassword(roomId, external_id,
  /// u16Secret)`：`RoomPassword.encodeJoin(isPrivate: false)` 生成
  /// base64(6 字节 joinPublic 头 XOR u16Secret) + roomId。观战需要 MyCard
  /// 登录（u16Secret 参与编码）。
  Future<void> _watch(SpectateRoom room) async {
    final account = await requireMyCardAccount(context, reason: '进入观战');
    if (account == null || !mounted) return; // 用户取消登录
    try {
      final u16Secret = await context.read<MyCardAccountApi>().fetchU16Secret();
      if (!mounted) return;
      final password = RoomPassword.encodeJoin(
        roomId: room.id,
        secret: u16Secret,
        isPrivate: false,
      );
      final matchStore = context.read<MatchStore>();
      matchStore.selectSpectate(
        widget.server,
        password,
        roomName: room.playersLabel,
        username: account.username,
      );
      final params = matchStore.toDuelRoomParams();
      ServiceSingleton.instance.ygoSoundService.playButtonTap();
      Navigator.of(context).pop();
      if (context.mounted) {
        context.go(widget.server.duelRoomPath, extra: params);
      }
      matchStore.reset();
    } on MyCardAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('进入观战失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return sheetContainer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.server.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_service.isConnecting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.server.wsUrl}  ·  ${widget.server.description}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_service.error != null) {
      return _StatusHint(
        message: '连接观战服务器失败',
        actionLabel: '重试',
        onAction: () => _service.connect(),
      );
    }
    final rooms = _service.rooms;
    if (rooms.isEmpty) {
      if (_service.isConnecting) {
        return const Center(child: CircularProgressIndicator());
      }
      return const _StatusHint(message: '暂无进行中的对局');
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0x22FFFFFF)),
      itemBuilder: (context, i) => _RoomTile(
        room: rooms[i],
        onTap: () => _watch(rooms[i]),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final SpectateRoom room;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                room.playersLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.modeLabel,
                style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.visibility, size: 16, color: Colors.amber.shade700),
          ],
        ),
      ),
    );
  }
}

class _StatusHint extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusHint({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}