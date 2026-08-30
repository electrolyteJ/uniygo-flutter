import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 居中展示服务端要求查看的多张卡（MSG_CONFIRM_CARDS 的 panel_confirm）。
///
/// 对照 room1 confirm_cards_dialog.dart：卡组 / 额外卡组中的多张卡经弹窗
/// 展示，玩家点击弹窗任意处、右上关闭钮或底部确认按钮均可关闭（不回包，
/// 服务端已在收到消息时自动确认）。视觉改走 room3 的赛博暗色 [HudTheme]，
/// 与 room1 的硬编码配色脱钩，保持整个 HUD 风格统一。
class ConfirmCardsDialog extends StatelessWidget {
  const ConfirmCardsDialog({
    super.key,
    required this.title,
    required this.codes,
    required this.cardNameBuilder,
    this.onDismiss,
  });

  final String title;
  final List<int> codes;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 弹窗根节点铺满全屏（Center 撑满父约束）：点任意处即关闭。
      // 卡图无逐张动作，点卡同样走关闭，对齐 room1「点击任意处关闭」。
      onTap: onDismiss,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: HudTheme.glowPanel(radius: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                Flexible(
                  child: codes.isEmpty
                      ? const Center(
                          child: Text('没有可查看的卡片', style: HudTheme.caption),
                        )
                      : _buildGrid(),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HudTheme.cyanDim,
                  ),
                  onPressed: onDismiss,
                  child: const Text('确认'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.visibility, color: HudTheme.cyan, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HudTheme.title.copyWith(color: HudTheme.cyan),
          ),
        ),
        Text('${codes.length} 张', style: HudTheme.caption),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onDismiss,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.close,
              color: HudTheme.textSecondary,
              size: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: codes.length,
      itemBuilder: (context, index) {
        final code = codes[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CardImage(
                    code: code,
                    width: 96,
                    height: 138,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cardNameBuilder(code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HudTheme.caption.copyWith(
                color: HudTheme.textPrimary,
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }
}
