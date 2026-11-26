/// 观战位入口（05a 等候房）：叠放头像，点击打开观战列表弹窗。
///
/// 有几个观战者就叠几个头像（不受观战位上限约束）；0 人时显示一个空位占位。
library;

import 'package:flutter/material.dart';

import 'duel_style.dart';

class SpectatorStackIcon extends StatelessWidget {
  const SpectatorStackIcon({
    super.key,
    required this.count,
    required this.onTap,
  });

  /// 当前观战人数。
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;

    final shown = count < 0 ? 0 : count;
    final avatar = s(16);
    final overlap = avatar * 0.55;
    final stackWidth =
        shown == 0 ? avatar : avatar + (shown - 1) * (avatar - overlap);

    Widget slot(int index) => Container(
      key: ValueKey('spectator-avatar-' + index.toString()),
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF16303F),
        border: Border.all(color: duelCyan, width: 0.8),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: avatar * 0.6, color: duelCyan),
    );

    Widget emptySlot() => Container(
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF09121C),
        border: Border.all(color: duelLine, width: 0.8),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: avatar * 0.6,
        color: duelSub,
      ),
    );

    return Tooltip(
      message: '观战 ' + count.toString(),
      child: InkWell(
        key: const ValueKey('waiting-spectators-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(2 * k),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s(6), vertical: s(3)),
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
                      emptySlot()
                    else
                      for (var i = 0; i < shown; i++)
                        Positioned(
                          left: i * (avatar - overlap),
                          child: slot(i),
                        ),
                  ],
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
