import 'package:flutter/material.dart';

/// 紧凑 HUD 模式（小屏）的玩家状态芯片：替代世界内竖版状态卡
///（两张 224 高的竖卡在手机上随场地 zoom 缩到不可读且互相重叠）。
///
/// 横排单行：头像（首字母）→ 名字 → LP 大数字 → H/D/EX/GY/B 计数；
/// EX/GY/B 可点（区域浏览器），语义与世界内状态卡一致。
class PlayerStatusChip extends StatelessWidget {
  const PlayerStatusChip({
    super.key,
    required this.name,
    required this.lp,
    required this.handCount,
    required this.deckCount,
    required this.extraCount,
    required this.graveCount,
    required this.removedCount,
    required this.isSelf,
    this.onZoneTap,
  });

  final String name;
  final int lp;
  final int handCount;
  final int deckCount;
  final int extraCount;
  final int graveCount;
  final int removedCount;

  /// 我方（青色系）/对方（粉红系）配色与交互归属。
  final bool isSelf;

  /// EX/GY/B 计数点击回调（区域浏览器 key：self_extra 等）。
  final void Function(String zoneKey)? onZoneTap;

  static const _accent = Color(0xFF00F0FF);
  static const _oppBorder = Color(0xFFFF4B82);
  static const _oppLp = Color(0xFFFF9FBB);
  static const _subtitle = Color(0xFF8B9BB4);

  @override
  Widget build(BuildContext context) {
    final accent = isSelf ? _accent : _oppBorder;
    final lpColor = isSelf ? _accent : _oppLp;
    final prefix = isSelf ? 'self' : 'opp';
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6080E18),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像圆：渐变底 + 首字母。
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelf
                    ? const [_accent, Color(0xFF0077FF)]
                    : const [Color(0xFFFF6698), Color(0xFF9F2257)],
              ),
              border: Border.all(
                color: isSelf ? _accent : const Color(0xFFFF6698),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 名字（过长截断）与 LP 大数字。
          Text(
            name.length > 5 ? '${name.substring(0, 4)}…' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$lp',
            style: TextStyle(
              color: lpColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(width: 8),
          _count('H', handCount, null),
          _count('D', deckCount, null),
          _count('EX', extraCount, '${prefix}_extra'),
          _count('GY', graveCount, '${prefix}_grave'),
          _count('B', removedCount, '${prefix}_removed'),
        ],
      ),
    );
  }

  /// 单个计数段；[zoneKey] 非空时可点击（EX/GY/B 开区域浏览器）。
  Widget _count(String label, int value, String? zoneKey) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: _subtitle, fontSize: 9),
            ),
            TextSpan(
              text: '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontFamily: 'Orbitron'),
      ),
    );
    if (zoneKey == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onZoneTap?.call(zoneKey),
      child: child,
    );
  }
}
