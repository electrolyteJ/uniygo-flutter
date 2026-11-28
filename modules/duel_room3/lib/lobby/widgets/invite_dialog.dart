import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hud_theme.dart';
import '../../util/invite/duel_invite.dart';

/// 选手卡：头像 / 昵称 / 段位 / 出战卡组（可切换）/ 卡组校验 / LP / 准备态。

/// 05a4 房间邀请：房间号 + 二维码 + 复制房间号/分享链接。
void showInviteDialog(
  BuildContext context,
  String roomId, {
  String? host,
  int? port,
}) {
  // 深链格式；对方扫码后可直接拿到邀码（h/p 帮助扫码方选出同一环境）。
  final link = DuelInvite.buildLink(roomId, host: host, port: port);
  void copy(String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HudTheme.panelBg,
      title: const Text('邀请好友', style: HudTheme.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roomId,
              textAlign: TextAlign.center,
              style: HudTheme.title.copyWith(
                fontSize: roomId.length > 12 ? 12 : 26,
                letterSpacing: roomId.length > 12 ? 0 : 6,
                color: HudTheme.cyan,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: QrImageView(
                data: link,
                size: 150,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF05070F),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF05070F),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('把房间号或分享链接发给好友', style: HudTheme.caption),
            const SizedBox(height: 4),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: HudTheme.caption.copyWith(
                fontSize: 10,
                color: HudTheme.cyan,
              ),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => copy(roomId, '房间号已复制'),
          child: const Text('复制房间号'),
        ),
        TextButton(
          onPressed: () => copy(link, '分享链接已复制'),
          child: const Text('复制分享链接'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
