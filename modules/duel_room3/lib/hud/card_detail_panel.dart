import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import 'hud_theme.dart';

/// MDPro3 风格卡片详情面板：左侧滑入，大图 + 名称/攻守/效果文本。
class CardDetailPanel extends StatelessWidget {
  const CardDetailPanel({
    super.key,
    required this.code,
    required this.info,
    required this.onClose,
  });

  final int? code;
  final pkg.CardInfo? info;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = code;
    if (c == null || c <= 0) return const SizedBox.shrink();
    return Container(
      width: 210,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: HudTheme.glowPanel(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info?.name ?? 'Card #$c',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HudTheme.title,
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: HudTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CardImage(code: c, width: 160, height: 233),
            ),
          ),
          if (info != null) ...[
            const SizedBox(height: 8),
            if (info!.attack >= 0)
              Text(
                'ATK ${info!.attack} / DEF ${info!.defense}',
                style: HudTheme.body.copyWith(color: HudTheme.gold),
              ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  info!.desc,
                  style: HudTheme.caption.copyWith(
                    color: HudTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
