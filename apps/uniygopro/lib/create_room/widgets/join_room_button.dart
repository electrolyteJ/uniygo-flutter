/// 加入好友房间：扫码（移动端）/ 粘贴邀请码（桌面、Web）后进房。
library;

import 'package:flutter/material.dart';

import 'package:duel_room3/util/invite/duel_invite.dart';
import 'package:duel_room3/util/invite/qr_scan_dialog.dart';
import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

import '../../config/servers.dart';
import '../../util/snack_bar_util.dart';
import '../free/free_room_launch.dart';

/// 从邀请信息推断进房环境：
/// - 233 房间串（含 `#`）固定是 mercury233；
/// - 二维码带了房主服务器地址时按 host/port 精确匹配；
/// - 都没有则退回当前页签选中的环境（仅限可用邀请码加入的四种）。
DuelEnvironment? resolveJoinEnvironment(
  DuelInvite invite,
  DuelEnvironment fallback,
) {
  if (invite.roomId.contains('#')) return DuelEnvironment.mercury233;
  final host = invite.host;
  final port = invite.port;
  if (host != null && port != null) {
    for (final env in DuelEnvironment.values) {
      if (env.host == host && env.port == port) return env;
    }
  }
  return switch (fallback) {
    DuelEnvironment.koishi ||
    DuelEnvironment.mycard ||
    DuelEnvironment.mercury233 ||
    DuelEnvironment.env408 => fallback,
    _ => null,
  };
}

/// 解析邀请文本并进房；[fallback] 为当前页签选中的环境。
Future<void> joinRoomByInviteText(
  BuildContext context,
  String raw, {
  required DuelEnvironment fallback,
}) async {
  final invite = DuelInvite.tryParse(raw);
  if (invite == null) {
    showSnackBar(context, '邀请码无法识别');
    return;
  }
  final env = resolveJoinEnvironment(invite, fallback);
  if (env == null) {
    showSnackBar(context, '该环境不支持用邀请码加入');
    return;
  }
  if (env == DuelEnvironment.koishi) {
    // Koishi 公共房没有"房主邀请"概念，密码由服务端分配，无法用邀码拉人。
    showSnackBar(context, 'Koishi 公共房不支持邀请码加入');
    return;
  }
  // MyCard 用房间 ID + u16Secret 现场编码；233/408 的房间串与邀码本身即密码。
  final password = env.useEncodedPassword ? '' : invite.roomId;
  await joinFreeRoom(
    context,
    env: env,
    roomId: invite.roomId,
    password: password,
  );
}

/// 「加入房间」按钮：扫码 / 粘贴邀请码后直接进房。
class JoinRoomButton extends StatelessWidget {
  const JoinRoomButton({super.key, required this.fallbackEnv});

  /// 当前页签选中的环境（邀请信息没带服务器提示时用它）。
  final DuelEnvironment fallbackEnv;

  Future<void> _onTap(BuildContext context) async {
    DuelSounds.dialogOpen();
    final raw = await showRoomQrScanDialog(context);
    if (raw == null || !context.mounted) return;
    await joinRoomByInviteText(context, raw, fallback: fallbackEnv);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      top: 8,
      width: 80,
      height: 30,
      child: DuelHit(
        key: const ValueKey('create-room-join'),
        onTap: () => _onTap(context),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A121C),
            border: Border.all(color: DuelColors.border),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 13,
                color: DuelColors.accent,
              ),
              const SizedBox(width: 6),
              Text('加入房间', style: DuelType.sans(9, color: DuelColors.textBody)),
            ],
          ),
        ),
      ),
    );
  }
}