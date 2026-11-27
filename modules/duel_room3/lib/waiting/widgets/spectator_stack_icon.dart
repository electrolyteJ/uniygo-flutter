/// 观战位入口（设计稿 05a「观战入口 · 优化」369:37）。
///
/// 120×26 胶囊：底色 #0A121B、描边 #152539、圆角 13；
/// 左侧三个「头 + 肩」小人叠加（灰 / 青 / 绿），右侧「观战 N」人数。
library;

import 'package:flutter/material.dart';

import 'duel_style.dart';

/// 三个小人的配色（设计稿：灰 / 青 / 绿）。
const List<Color> _avatarPalette = [duelFaint, duelCyan, duelHeal];

class SpectatorStackIcon extends StatelessWidget {
  const SpectatorStackIcon({
    super.key,
    required this.count,
    required this.onTap,
  });

  /// 当前观战人数（仅显示在右侧文案）。
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;

    final shown = count < 0 ? 0 : count;

    // 单个「人」= 头（8×8 圆）+ 肩（12×6 圆角矩形），整体 12×14。
    Widget person(int index) => SizedBox(
      width: s(12),
      height: s(14),
      child: Stack(
        children: [
          Positioned(
            left: s(2),
            top: 0,
            child: Container(
              width: s(8),
              height: s(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _avatarPalette[index % _avatarPalette.length],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: s(8),
            child: Container(
              width: s(12),
              height: s(6),
              decoration: BoxDecoration(
                color: _avatarPalette[index % _avatarPalette.length],
                borderRadius: BorderRadius.circular(s(3)),
              ),
            ),
          ),
        ],
      ),
    );

    return InkWell(
      key: const ValueKey('waiting-spectators-entry'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(s(13)),
      child: Container(
        width: s(120),
        height: s(26),
        decoration: BoxDecoration(
          color: const Color(0xFF0A121B),
          borderRadius: BorderRadius.circular(s(13)),
          border: Border.all(color: duelLine),
        ),
        child: Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: s(18 + i * 12),
                top: s(6),
                child: KeyedSubtree(
                  key: ValueKey('spectator-avatar-' + i.toString()),
                  child: person(i),
                ),
              ),
            Positioned(
              left: s(62),
              top: s(4),
              child: Text(
                '观战 ' + shown.toString(),
                style: TextStyle(fontSize: s(9), color: duelMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
