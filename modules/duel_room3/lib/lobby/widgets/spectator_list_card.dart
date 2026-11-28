/// 05a5 观战列表浮层：人数 + 观战者列表 + 底部观战规则提示。
///
/// 只渲染实际观战者：有多少人就有多少条，不再补空位。
library;

import 'package:flutter/material.dart';

import '../../theme/duel_style.dart';

class SpectatorListCard extends StatelessWidget {
  const SpectatorListCard({
    super.key,
    required this.observerCount,
    required this.selfIsObserver,
    required this.onClose,
  });

  final int observerCount;
  final bool selfIsObserver;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;
    final count = observerCount < 0 ? 0 : observerCount;

    Widget row(int index) {
      final isSelf = selfIsObserver && index == 0;
      return Container(
        width: s(232),
        height: s(30),
        margin: EdgeInsets.only(bottom: s(6)),
        padding: EdgeInsets.symmetric(horizontal: s(10)),
        decoration: BoxDecoration(
          color: const Color(0xFF09121C),
          borderRadius: BorderRadius.circular(s(2)),
          border: Border.all(color: isSelf ? duelCyan : duelLine),
        ),
        child: Row(
          children: [
            Icon(Icons.person, size: s(16), color: isSelf ? duelCyan : duelSub),
            SizedBox(width: s(6)),
            Text(
              isSelf ? '你' : '观战玩家 ${index + 1}',
              style: TextStyle(
                fontSize: s(8.5),
                color: isSelf ? duelCyan : duelTextColor,
              ),
            ),
            const Spacer(),
            Text(
              '观战位 ${index + 1}',
              style: TextStyle(fontSize: s(8), color: duelFaint),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: s(260),
      height: s(286),
      child: Container(
        decoration: BoxDecoration(
          color: duelPanel,
          border: Border.all(color: duelLine),
          borderRadius: BorderRadius.circular(s(2)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: s(260),
              height: s(2),
              child: const ColoredBox(color: duelCyan),
            ),
            Positioned(
              left: s(14),
              top: s(12),
              child: Text(
                '观战列表',
                style: TextStyle(fontSize: s(10.5), color: duelTextColor),
              ),
            ),
            Positioned(
              right: s(10),
              top: s(8),
              child: GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: s(12), color: duelMuted),
              ),
            ),
            Positioned(
              left: s(14),
              top: s(30),
              child: Text(
                '观战 ' + count.toString() + ' · 仅好友可观看',
                style: TextStyle(fontSize: s(7), color: duelFaint),
              ),
            ),
            if (count == 0) ...[
              Positioned(
                left: s(14),
                top: s(108),
                child: Text(
                  '暂无观战玩家',
                  style: TextStyle(fontSize: s(8.5), color: duelSub),
                ),
              ),
              Positioned(
                left: s(14),
                top: s(126),
                child: Text(
                  '邀请好友观战后可在此查看',
                  style: TextStyle(fontSize: s(7), color: duelFaint),
                ),
              ),
            ] else
              Positioned(
                left: s(14),
                top: s(48),
                width: s(232),
                height: s(190),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (var i = 0; i < count; i++) row(i)],
                  ),
                ),
              ),
            Positioned(
              left: s(14),
              top: s(256),
              width: s(232),
              child: Text(
                '观战者仅可查看双方手牌以外的场面',
                style: TextStyle(fontSize: s(7), color: duelFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
