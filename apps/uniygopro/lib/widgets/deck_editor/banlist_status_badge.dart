import 'package:flutter/material.dart';

Color? banlistStatusColor(BuildContext context, String? status) {
  switch (status) {
    case '禁止':
      return Theme.of(context).colorScheme.error;
    case '限制':
      return Colors.orange;
    case '准限制':
      return Colors.yellow.shade700;
    default:
      return null;
  }
}

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

class BanlistDot extends StatelessWidget {
  const BanlistDot({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = banlistStatusColor(context, status);
    if (color == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: status,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class BanlistCornerBadge extends StatelessWidget {
  const BanlistCornerBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = banlistStatusColor(context, status);
    if (color == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: status,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          banlistStatusShortLabel(status),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
