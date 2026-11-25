/// 加入房间的小输入框：房间号（MyCard/233 需要）+ 密码。
library;

import 'package:flutter/material.dart';

import '../../config/servers.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

/// 返回 (房间号, 密码)；取消返回 null。
Future<({String roomId, String password})?> showJoinRoomDialog(
  BuildContext context, {
  required DuelEnvironment env,
  String initialRoomId = '',
}) {
  final roomCtrl = TextEditingController(text: initialRoomId);
  final pwCtrl = TextEditingController();
  // MyCard 私密房：只需要朋友分享的私密房 ID（密码由 u16Secret 现场编码）。
  // Koishi / 233 只需要密码（233 的房间串本身即密码）。
  final needRoomId = env == DuelEnvironment.mycard;
  final needPassword = env != DuelEnvironment.mycard;

  InputDecoration deco(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    labelStyle: DuelType.sans(9, color: DuelColors.textMuted),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: DuelColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: DuelColors.accent),
    ),
  );

  return showDialog<({String roomId, String password})>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF080F19),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: DuelColors.borderPanel),
      ),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('加入房间', style: DuelType.sans(12)),
              const SizedBox(height: 4),
              Text(
                env.displayName,
                style: DuelType.sans(8, color: DuelColors.textFaint),
              ),
              const SizedBox(height: 12),
              if (needRoomId) ...[
                TextField(
                  key: const ValueKey('join-room-id'),
                  controller: roomCtrl,
                  style: DuelType.sans(10, color: DuelColors.textPrimary),
                  decoration: deco('房间号'),
                ),
                const SizedBox(height: 10),
              ],
              if (needPassword)
                TextField(
                  key: const ValueKey('join-room-password'),
                  controller: pwCtrl,
                  style: DuelType.sans(10, color: DuelColors.textPrimary),
                  decoration: deco(
                    env == DuelEnvironment.mercury233 ? '房间串 / 密码' : '密码',
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      DuelSounds.dialogClose();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      '取消',
                      style: DuelType.sans(10, color: DuelColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('join-room-submit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DuelColors.accent,
                      foregroundColor: DuelColors.inkOnAccent,
                    ),
                    onPressed: () {
                      DuelSounds.tabSwitch();
                      Navigator.of(ctx).pop((
                        roomId: roomCtrl.text.trim(),
                        password: pwCtrl.text.trim(),
                      ));
                    },
                    child: Text('加入', style: DuelType.sans(10)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
