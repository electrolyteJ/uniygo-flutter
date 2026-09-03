import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

/// 卡详情抽屉宽度：以卡图宽度为上限（不再固定 440），
/// 只留卡图 + 左右内边距(14×2) + 描边(1.6×2) 的宽度。
double cardDetailDrawerWidth(DuelRoomLayoutSpec spec) {
  final desiredCardWidth = spec.isCompact ? 160.0 : 206.0 * spec.hudScale;
  return desiredCardWidth + 14.0 * 2 + 1.6 * 2;
}

Rect cardDetailDrawerRect(DuelRoomLayoutSpec spec) {
  final left = (spec.safeRect.left + spec.panelGap)
      .clamp(spec.safeRect.left, spec.safeRect.right)
      .toDouble();
  final top = spec.isCompact
      ? spec.safeRect.top + spec.topHudHeight + 8
      : (124.0 > spec.safeRect.top + spec.topHudHeight + 8
            ? 124.0
            : spec.safeRect.top + spec.topHudHeight + 8);
  final bottomInset = spec.isCompact
      ? spec.safePadding.bottom + spec.handBarHeight + 8
      : (160.0 > spec.safePadding.bottom + spec.panelGap
            ? 160.0
            : spec.safePadding.bottom + spec.panelGap);
  final rightEdge = (left + cardDetailDrawerWidth(spec))
      .clamp(left, spec.safeRect.right)
      .toDouble();
  final bottom = (spec.viewport.height - bottomInset)
      .clamp(top, spec.safeRect.bottom)
      .toDouble();
  return Rect.fromLTRB(left, top, rightEdge, bottom);
}

class CardDetailDrawer extends StatelessWidget {
  final CardInfo? cardInfo;
  final int? cardCode;
  final VoidCallback? onClose;

  const CardDetailDrawer({
    super.key,
    this.cardInfo,
    this.cardCode,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const goldGlow = Color(0xFFFFD700);
    const panelDark = Color(0xF1080C14);
    // 高度由父级 Positioned(top/bottom) 约束决定，自适应屏幕。
    final resolvedCode = cardInfo?.code ?? cardCode ?? 0;
    // 响应式：宽度夹紧不溢出窄屏；卡图尺寸由实际内容宽度决定。
    final spec = DuelRoomLayout.of(context);
    final hs = spec.hudScale;
    final panelWidth = cardDetailDrawerWidth(spec);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: panelWidth,
          decoration: BoxDecoration(
            color: panelDark,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x6600F0FF), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: cyanGlow.withValues(alpha: 0.12),
                blurRadius: 36,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 48,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 3),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x2200F0FF))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '卡片详情',
                      style: TextStyle(
                        color: cyanGlow,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 0.9,
                      ),
                    ),
                    if (onClose != null)
                      Tooltip(
                        message: '关闭',
                        child: Semantics(
                          label: '关闭',
                          button: true,
                          enabled: true,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: const ValueKey('card-detail-close'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onClose,
                            child: const SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: Icon(
                                  Icons.close,
                                  color: cyanGlow,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final desiredCardWidth = spec.isCompact
                          ? 160.0
                          : 206.0 * hs;
                      final cardW = math.min(
                        desiredCardWidth,
                        constraints.maxWidth,
                      );
                      final cardH = cardW * 294 / 206;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              key: const ValueKey('card-detail-image'),
                              width: cardW,
                              height: cardH,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1624),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cyanGlow, width: 1.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: cyanGlow.withValues(alpha: 0.26),
                                    blurRadius: 26,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              // 无有效卡密时不发请求，渲染静态占位
                              child: resolvedCode > 0
                                  ? CardImage(
                                      code: resolvedCode,
                                      width: cardW,
                                      height: cardH,
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Color(0xFF8B9BB4),
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            cardInfo?.name ??
                                (cardCode != null
                                    ? 'Card #$cardCode'
                                    : 'Unknown'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Rajdhani',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (cardInfo != null) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(cardInfo!.kindLabel, goldGlow),
                                if (cardInfo!.isMonster) ...[
                                  // 等级徽标分类型：XYZ 的 level 存负值（阶级），
                                  // 连接的 level 是 LINK 值而非星级。
                                  _buildBadge(
                                    cardInfo!.isLink
                                        ? 'LINK-${cardInfo!.level}'
                                        : cardInfo!.isXyz
                                        ? '${-cardInfo!.level}阶'
                                        : '${cardInfo!.level}星',
                                    goldGlow,
                                  ),
                                  _buildBadge(
                                    cardInfo!.attributeText,
                                    goldGlow,
                                  ),
                                  _buildBadge(cardInfo!.raceText, goldGlow),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (cardInfo!.isMonster)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatText(
                                      'ATK',
                                      '${cardInfo!.attack < 0 ? '?' : cardInfo!.attack}',
                                      const Color(0xFFFF5A94),
                                    ),
                                    if (!cardInfo!.isLink)
                                      _buildStatText(
                                        'DEF',
                                        '${cardInfo!.defense < 0 ? '?' : cardInfo!.defense}',
                                        cyanGlow,
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),

                            // 描述区域：随抽屉整体滚动（小屏不再内嵌滚动，
                            // 避免卡图+徽章+攻防固定高度把描述挤没）。
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                cardInfo!.desc,
                                style: const TextStyle(
                                  color: Color(0xFF8B9BB4),
                                  fontSize: 12,
                                  height: 1.5,
                                  fontFamily: 'Noto Sans SC',
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatText(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Colors.white,
        ),
        children: [
          TextSpan(text: '$label / '),
          TextSpan(
            text: value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
