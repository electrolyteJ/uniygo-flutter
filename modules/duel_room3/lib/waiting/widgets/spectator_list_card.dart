/// 05a5 观战列表浮层：观战位 1/2 + 空态 + 底部观战规则提示。
library;

import 'package:flutter/material.dart';

import 'duel_style.dart';

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

    Widget slot(int index) {
      final occupied = index < observerCount;
      final isSelfSlot = occupied && selfIsObserver && index == 0;
      return Padding(
        padding: EdgeInsets.only(bottom: s(8)),
        child: Container(
          width: s(232),
          height: s(30),
          padding: EdgeInsets.symmetric(horizontal: s(10)),
          decoration: BoxDecoration(
            color: const Color(0xFF09121C),
            borderRadius: BorderRadius.circular(s(2)),
            border: Border.all(color: isSelfSlot ? duelCyan : duelLine),
          ),
          child: Row(
            children: [
              Text(
                '观战位 ' + (index + 1).toString(),
                style: TextStyle(fontSize: s(8.5), color: duelSub),
              ),
              const Spacer(),
              if (occupied)
                Text(
                  isSelfSlot ? '你' : '观战玩家',
                  style: TextStyle(
                    fontSize: s(8.5),
                    color: isSelfSlot ? duelCyan : duelTextColor,
                  ),
                )
              else
                Text(
                  '空位',
                  style: TextStyle(fontSize: s(8.5), color: duelFaint),
                ),
            ],
          ),
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
                '观战 ' + observerCount.toString() + ' / 2 · 仅好友可观看',
                style: TextStyle(fontSize: s(7), color: duelFaint),
              ),
            ),
            Positioned(
              left: s(14),
              top: s(108),
              child: Text(
                observerCount == 0 ? '暂无观战玩家' : '观战玩家',
                style: TextStyle(fontSize: s(8.5), color: duelSub),
              ),
            ),
            Positioned(
              left: s(14),
              top: s(126),
              child: Text(
                observerCount == 0 ? '邀请好友观战后可在此查看' : '仅好友可观看本局',
                style: TextStyle(fontSize: s(7), color: duelFaint),
              ),
            ),
            Positioned(left: s(14), top: s(152), child: slot(0)),
            Positioned(left: s(14), top: s(190), child: slot(1)),
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
