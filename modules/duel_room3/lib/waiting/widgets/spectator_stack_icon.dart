/// 观战位入口（05a 等候房）：叠放头像 + 人数，点击打开观战列表弹窗。
///
/// 观战人数与 [DuelRoomState.observerCount] 一致：有几个观战者就叠几个头像；
/// 0 人时显示一个空位占位。
library;

import 'package:flutter/material.dart';

import 'duel_style.dart';

class SpectatorStackIcon extends StatelessWidget {
  const SpectatorStackIcon({
    super.key,
    required this.count,
    required this.onTap,
    this.maxSlots = 2,
  });

  /// 当前观战人数。
  final int count;

  /// 观战位上限（用于文案 N / maxSlots）。
  final int maxSlots;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;

    final shown = count.clamp(0, maxSlots);
    final avatar = s(16);
    final overlap = avatar * 0.55;
    final stackWidth =
        shown == 0 ? avatar : avatar + (shown - 1) * (avatar - overlap);

    Widget slot({bool filled = false}) => Container(
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? const Color(0xFF16303F) : const Color(0xFF09121C),
        border: Border.all(
          color: filled ? duelCyan : duelLine,
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        filled ? Icons.person : Icons.person_outline,
        size: avatar * 0.6,
        color: filled ? duelCyan : duelSub,
      ),
    );

    return Tooltip(
      message: '观战列表 ' + count.toString() + ' / ' + maxSlots.toString(),
      child: InkWell(
        key: const ValueKey('waiting-spectators-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(2 * k),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s(7), vertical: s(3)),
          decoration: BoxDecoration(
            color: duelPanel,
            borderRadius: BorderRadius.circular(2 * k),
            border: Border.all(color: duelLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: stackWidth,
                height: avatar,
                child: Stack(
                  children: [
                    if (shown == 0)
                      slot()
                    else
                      for (var i = 0; i < shown; i++)
                        Positioned(
                          left: i * (avatar - overlap),
                          child: slot(filled: true),
                        ),
                  ],
                ),
              ),
              SizedBox(width: s(6)),
              Text(
                '观战 ' + count.toString() + ' / ' + maxSlots.toString(),
                style: TextStyle(
                  fontSize: s(7.5),
                  color: count > 0 ? duelTextColor : duelSub,
                ),
              ),
              Icon(Icons.chevron_right, size: s(11), color: duelSub),
            ],
          ),
        ),
      ),
    );
  }
}
