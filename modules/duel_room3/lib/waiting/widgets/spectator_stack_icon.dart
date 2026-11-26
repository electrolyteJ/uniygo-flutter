/// 观战位入口（05a8 观战者视角 · 观战头像堆叠）。
///
/// 按设计稿 05a8 的「观战头像堆叠」：20px 圆形头像、相邻重叠 6px、
/// 底色描边分隔；右侧跟「观战 N」人数。有几个观战者就叠几个头像。
library;

import 'package:flutter/material.dart';

import 'duel_style.dart';

/// 堆叠头像配色（设计稿：暗青 / 青 / 绿三色循环）。
const List<Color> _avatarPalette = [duelTeal, duelCyan, duelHeal];

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
    final avatar = s(20);
    final step = s(14); // 20px 头像重叠 6px
    final stackWidth = shown == 0 ? avatar : avatar + (shown - 1) * step;

    Widget avatarCircle(int index) => Container(
      key: ValueKey('spectator-avatar-' + index.toString()),
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarPalette[index % _avatarPalette.length],
        // 与页面底色一致的描边，制造叠放的分隔边。
        border: Border.all(color: duelBg, width: s(1.5)),
      ),
    );

    Widget emptyCircle() => Container(
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: duelTeal.withValues(alpha: 0.35),
        border: Border.all(color: duelLine, width: s(1)),
      ),
    );

    return InkWell(
      key: const ValueKey('waiting-spectators-entry'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(2 * k),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s(2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: stackWidth,
              height: avatar,
              child: Stack(
                children: [
                  if (shown == 0)
                    emptyCircle()
                  else
                    for (var i = 0; i < shown; i++)
                      Positioned(left: i * step, child: avatarCircle(i)),
                ],
              ),
            ),
            SizedBox(width: s(6)),
            Text(
              '观战 ' + shown.toString(),
              style: TextStyle(fontSize: s(7.5), color: duelMuted),
            ),
          ],
        ),
      ),
    );
  }
}
