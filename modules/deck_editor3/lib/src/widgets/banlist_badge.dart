import 'package:flutter/material.dart';

/// 禁限状态 → 角标底色（禁止/限制/准限制）。
Color? banlistStatusColor(String? status) {
  switch (status) {
    case '禁止':
      return const Color(0xFFFF4D4D);
    case '限制':
      return const Color(0xFFFF9800);
    case '准限制':
      return const Color(0xFFFDD835);
    default:
      return null;
  }
}

/// 禁限状态的单字角标文案（禁止→禁，限制→限，准限制→准）。
String banlistStatusShortLabel(String status) {
  switch (status) {
    case '禁止':
      return '禁';
    case '限制':
      return '限';
    case '准限制':
      return '准';
    default:
      return status;
  }
}

/// 卡片左上角的禁限角标：禁止/限制/准限制用单字胶囊提示，无限制不显示。
///
/// 供卡池卡片与卡组分区卡片共用，替代原来的横幅式禁限展示。
class BanlistCornerBadge extends StatelessWidget {
  const BanlistCornerBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = banlistStatusColor(status);
    if (color == null) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: status,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          banlistStatusShortLabel(status),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
