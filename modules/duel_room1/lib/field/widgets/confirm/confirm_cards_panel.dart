import 'package:flutter/material.dart';

import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/field/widgets/docked_panel_shell.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

/// 确认卡列表面板（MSG_CONFIRM_CARDS 多张非场上卡）。
///
/// 确认消息只展示、不回包、不阻塞对局，因此不做居中模态：
/// 右停靠面板（几何见 [DockedPanelShell]），面板外点击穿透到场地，
/// 关闭只走右上角 × 按钮（[onDismiss]）。
///
/// 到达时右滑入 + 淡入（约 220ms）以提醒玩家；之后常驻直到手动关闭，
/// 不自动消退——确认卡需要逐张读，阅读节奏由玩家掌控。
///
/// 点击卡片经 [onInspectCard] 打开卡片详情抽屉（纯检视、不回包，
/// 与场地/手牌的点卡检视同一链路）。
class ConfirmCardsPanel extends StatelessWidget {
  final String title;
  final List<int> codes;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;

  /// 点击卡片查看详情；为 null 时卡片不响应点击。
  final void Function(int code)? onInspectCard;

  const ConfirmCardsPanel({
    super.key,
    required this.title,
    required this.codes,
    required this.cardNameBuilder,
    this.onDismiss,
    this.onInspectCard,
  });

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    // 进场动画（右滑入+淡入）由 DockedPanelShell 统一提供；
    // 父级按 ConfirmPanel 实例换 key，每次新确认重播进场。
    return DockedPanelShell(
      title: title,
      count: codes.length,
      onClose: onDismiss,
      leading: const Icon(
        Icons.visibility,
        color: DockedPanelShell.accent,
        size: 20,
      ),
      child: codes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  '没有可查看的卡片',
                  style: TextStyle(
                    color: DockedPanelShell.subtitle,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Noto Sans SC',
                  ),
                ),
              ),
            )
          : GridView.builder(
              key: const ValueKey('confirm-cards-grid'),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: spec.isCompact ? 2 : spec.gridColumns,
                mainAxisSpacing: DockedPanelShell.gridSpacing,
                crossAxisSpacing: DockedPanelShell.gridSpacing,
                childAspectRatio: DockedPanelShell.gridAspect,
              ),
              itemCount: codes.length,
              itemBuilder: (context, index) {
                final code = codes[index];
                return _ConfirmCardTile(
                  code: code,
                  name: cardNameBuilder(code),
                  onTap: onInspectCard == null
                      ? null
                      : () => onInspectCard!(code),
                );
              },
            ),
    );
  }
}

class _ConfirmCardTile extends StatelessWidget {
  final int code;
  final String name;

  /// 点击卡片查看详情；为 null 时整格不响应点击。
  final VoidCallback? onTap;

  const _ConfirmCardTile({required this.code, required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = constraints.maxWidth.clamp(0.0, 150.0);
        final maxCardHeight = (constraints.maxHeight - 36).clamp(0.0, 215.0);
        final cardScale = [
          maxCardWidth / 150,
          maxCardHeight / 215,
          1.0,
        ].reduce((value, element) => value < element ? value : element);
        final cardWidth = 150 * cardScale;
        final cardHeight = 215 * cardScale;

        final tile = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CardImage(
                    code: code,
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD7E3F2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Sans SC',
                height: 1.25,
              ),
            ),
          ],
        );
        if (onTap == null) return tile;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: tile),
        );
      },
    );
  }
}
